import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:CallSos/core/app_routes.dart';
import 'package:CallSos/data/models/auth_result.dart';
import 'package:CallSos/data/models/enums/rol.dart';
import 'package:CallSos/data/services/api_exception.dart';
import 'package:CallSos/data/services/auth_service.dart';
import 'package:CallSos/data/services/reporte_service.dart';
import 'package:CallSos/data/services/secure_storage.dart';
import 'package:CallSos/presentation/viewmodels/sesion_viewmodel.dart';
import 'package:CallSos/presentation/views/reporte_hallazgos_view.dart';

/// Épica 5 (ruta técnica) — widget test de ReporteHallazgosView.
///
/// Punto central a cubrir (documentado como decisión de diseño en el
/// propio código, F.4): el envío exitoso llama SOLO a
/// `IReporteService.crearHallazgos(...)` — nunca a `evaluar()` — porque
/// el backend finaliza el incidente dentro de ese mismo POST. Llamar
/// evaluar() aparte causaría un 422 (el incidente ya habría pasado a
/// FINALIZADO). Esta vista no depende de IIncidenteService en absoluto.
class MockAuthService extends Mock implements IAuthService {}

class MockReporteService extends Mock implements IReporteService {}

class FakeSecureStorage implements ISecureStorage {
  final Map<String, String> _datos = {};
  @override
  Future<String?> read(String key) async => _datos[key];
  @override
  Future<void> write(String key, String value) async => _datos[key] = value;
  @override
  Future<void> delete(String key) async => _datos.remove(key);
}

void main() {
  late MockAuthService authService;
  late MockReporteService reporteService;
  late SesionViewModel sesion;

  setUp(() async {
    authService = MockAuthService();
    reporteService = MockReporteService();
    sesion = SesionViewModel(authService: authService, storage: FakeSecureStorage());

    when(() => authService.login(username: 'ag-001', password: '1234')).thenAnswer(
      (_) async => const AuthResult(
          token: 'jwt-agente', actorId: 'ag-001', rol: Rol.AGENTE, nombre: 'Carlos Agente'),
    );
    await sesion.login(username: 'ag-001', password: '1234');
  });

  Widget appDePrueba({String incidenteId = 'i-001'}) {
    return MultiProvider(
      providers: [
        Provider<IReporteService>.value(value: reporteService),
        ChangeNotifierProvider<SesionViewModel>.value(value: sesion),
      ],
      child: MaterialApp(
        onGenerateRoute: (_) => MaterialPageRoute(
          builder: (_) => const ReporteHallazgosView(),
          settings: RouteSettings(arguments: {'incidenteId': incidenteId}),
        ),
        routes: {
          AppRoutes.homeAgente: (_) => const Scaffold(body: Text('home_agente')),
        },
      ),
    );
  }

  testWidgets('botón "Enviar reporte" deshabilitado con descripción vacía',
      (tester) async {
    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();

    final boton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Enviar reporte'),
    );
    expect(boton.onPressed, isNull);
  });

  testWidgets(
      'con descripción, envío exitoso llama crearHallazgos(incidenteId, descripcion) '
      '— el agenteId ya NO se envía en el body (Épica 8: el backend lo saca del '
      'JWT) — NUNCA evaluar() (no existe IIncidenteService en este árbol) — navega '
      'a HomeAgenteView limpiando el stack y muestra el snackbar', (tester) async {
    when(() => reporteService.crearHallazgos(
          incidenteId: 'i-001',
          descripcion: 'Todo en orden al llegar.',
        )).thenAnswer((_) async => ReporteHallazgosResult(
          id: 'rep-001',
          fecha: DateTime(2026, 6, 14, 11, 0),
          incidenteId: 'i-001',
          agenteId: 'ag-001',
        ));

    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Todo en orden al llegar.');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Enviar reporte'));
    await tester.pumpAndSettle();

    verify(() => reporteService.crearHallazgos(
          incidenteId: 'i-001',
          descripcion: 'Todo en orden al llegar.',
        )).called(1);
    expect(find.text('home_agente'), findsOneWidget);
    expect(find.textContaining('Reporte enviado'), findsOneWidget);
    // El formulario ya no está en el árbol — pushNamedAndRemoveUntil
    // eliminó el stack completo.
    expect(find.byType(ReporteHallazgosView), findsNothing);
  });

  testWidgets('descripción solo con espacios en blanco mantiene el botón deshabilitado',
      (tester) async {
    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pumpAndSettle();

    final boton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Enviar reporte'),
    );
    expect(boton.onPressed, isNull);
  });

  testWidgets('error de negocio del backend se muestra inline y NO navega', (tester) async {
    when(() => reporteService.crearHallazgos(
          incidenteId: any(named: 'incidenteId'),
          descripcion: any(named: 'descripcion'),
        )).thenThrow(const ApiException(
      type: ApiExceptionType.businessRule,
      message: 'El incidente ya no está en atención.',
    ));

    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Descripción cualquiera.');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Enviar reporte'));
    await tester.pumpAndSettle();

    expect(find.text('El incidente ya no está en atención.'), findsOneWidget);
    expect(find.byType(ReporteHallazgosView), findsOneWidget); // sigue en el formulario
  });

  testWidgets('botón "Cancelar" hace pop sin llamar a crearHallazgos()', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MultiProvider(
                providers: [
                  Provider<IReporteService>.value(value: reporteService),
                  ChangeNotifierProvider<SesionViewModel>.value(value: sesion),
                ],
                child: const ReporteHallazgosView(),
              ),
              settings: const RouteSettings(arguments: {'incidenteId': 'i-001'}),
            ),
          ),
          child: const Text('abrir'),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar'));
    await tester.pumpAndSettle();

    expect(find.byType(ReporteHallazgosView), findsNothing);
    verifyNever(() => reporteService.crearHallazgos(
          incidenteId: any(named: 'incidenteId'),
          descripcion: any(named: 'descripcion'),
        ));
  });

  // Bloque 4 (Épica 8) — pantalla chica + texto largo.
  group('Responsive', () {
    testWidgets('no desborda en pantalla chica (375x667)', (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(appDePrueba());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('no desborda escribiendo una descripción de ~200 caracteres',
        (tester) async {
      final descripcionLarga = 'Al llegar al lugar se encontró que la '
          'situación ya había sido resuelta por los vecinos del sector, '
          'no se encontraron elementos de interés criminalístico ni '
          'personas heridas, se recomienda hacer seguimiento preventivo '
          'en la zona durante los próximos días.'; // ~250 caracteres

      await tester.pumpWidget(appDePrueba());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), descripcionLarga);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final boton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Enviar reporte'),
      );
      expect(boton.onPressed, isNotNull);
    });
  });
}