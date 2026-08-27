import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:CallSos/core/app_routes.dart';
import 'package:CallSos/data/models/agente_disponible.dart';
import 'package:CallSos/data/models/auth_result.dart';
import 'package:CallSos/data/models/enums/estado_agente.dart';
import 'package:CallSos/data/models/enums/estado_incidente.dart';
import 'package:CallSos/data/models/enums/rol.dart';
import 'package:CallSos/data/models/enums/tipo_incidente_enum.dart';
import 'package:CallSos/data/models/incidente.dart';
import 'package:CallSos/data/services/api_exception.dart';
import 'package:CallSos/data/services/auth_service.dart';
import 'package:CallSos/data/services/cai_service.dart';
import 'package:CallSos/data/services/incidente_service.dart';
import 'package:CallSos/data/services/secure_storage.dart';
import 'package:CallSos/presentation/viewmodels/sesion_viewmodel.dart';
import 'package:CallSos/presentation/views/home_cai_view.dart';

/// Épica 5 (ruta técnica) — widget test de HomeCAIView.
///
/// Particularidad frente a HomeAgenteView/HomeDenuncianteView: tiene 2
/// tabs (Por Asignar / Historial) y su bottom sheet de asignación
/// consulta un servicio adicional (ICaiService.agentesDisponibles) antes
/// de confirmar — esta lista es solo informativa (ver el comentario de
/// diseño en home_cai_view.dart: la asignación real siempre es
/// automática, el backend no expone elegir un agente puntual todavía).
class MockAuthService extends Mock implements IAuthService {}

class MockIncidenteService extends Mock implements IIncidenteService {}

class MockCaiService extends Mock implements ICaiService {}

class FakeSecureStorage implements ISecureStorage {
  final Map<String, String> _datos = {};
  @override
  Future<String?> read(String key) async => _datos[key];
  @override
  Future<void> write(String key, String value) async => _datos[key] = value;
  @override
  Future<void> delete(String key) async => _datos.remove(key);
}

Incidente _fake(String id, EstadoIncidente estado) => Incidente(
      id: id,
      fechaHora: DateTime(2026, 6, 14),
      tipo: TipoIncidenteEnum.ROBOS_O_ASALTOS,
      descripcion: 'desc',
      estado: estado,
      latitud: 10.391,
      longitud: -75.4794,
      denuncianteId: 'den-001',
    );

void main() {
  late MockAuthService authService;
  late MockIncidenteService incidenteService;
  late MockCaiService caiService;
  late SesionViewModel sesion;

  setUp(() async {
    authService = MockAuthService();
    incidenteService = MockIncidenteService();
    caiService = MockCaiService();
    sesion = SesionViewModel(authService: authService, storage: FakeSecureStorage());

    when(() => authService.login(username: 'cai-001', password: '1234')).thenAnswer(
      (_) async => const AuthResult(
          token: 'jwt-cai', actorId: 'cai-001', rol: Rol.OPERADOR_CAI, nombre: 'CAI San José'),
    );
    await sesion.login(username: 'cai-001', password: '1234');
  });

  Widget appDePrueba() {
    return MultiProvider(
      providers: [
        Provider<IIncidenteService>.value(value: incidenteService),
        Provider<ICaiService>.value(value: caiService),
        ChangeNotifierProvider<SesionViewModel>.value(value: sesion),
      ],
      child: MaterialApp(
        home: const HomeCAIView(),
        routes: {
          AppRoutes.detalleIncidente: (_) => const Scaffold(body: Text('detalle_incidente')),
          AppRoutes.roleSelection: (_) => const Scaffold(body: Text('role_selection')),
        },
      ),
    );
  }

  testWidgets('carga /por-cai al iniciar y muestra "Panel CAI" + nombre del operador',
      (tester) async {
    when(() => incidenteService.porCai()).thenAnswer((_) async => []);

    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();

    verify(() => incidenteService.porCai()).called(1);
    expect(find.text('Panel CAI'), findsOneWidget);
    expect(find.text('CAI San José'), findsOneWidget);
  });

  testWidgets('tab "Por Asignar" solo muestra DERIVADO_A_CAI; "Historial" muestra el resto',
      (tester) async {
    when(() => incidenteService.porCai()).thenAnswer((_) async => [
          _fake('i-001', EstadoIncidente.DERIVADO_A_CAI),
          _fake('i-002', EstadoIncidente.FINALIZADO),
        ]);

    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();

    // Tab inicial: "Por Asignar" — solo i-001 (mostrado como botón "Asignar Agente").
    expect(find.text('Asignar Agente'), findsOneWidget);

    await tester.tap(find.text('Historial'));
    await tester.pumpAndSettle();

    // En Historial, i-002 se muestra sin botón de acción propio.
    expect(find.text('Asignar Agente'), findsNothing);
  });

  testWidgets(
      'tocar "Asignar Agente" abre el sheet y consulta agentesDisponibles(caiId) '
      'con el actorId de la sesión', (tester) async {
    when(() => incidenteService.porCai())
        .thenAnswer((_) async => [_fake('i-001', EstadoIncidente.DERIVADO_A_CAI)]);
    when(() => caiService.agentesDisponibles('cai-001')).thenAnswer((_) async => [
          const AgenteDisponible(id: 'ag-001', nombre: 'Carlos Agente', estado: EstadoAgente.DISPONIBLE),
        ]);

    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Asignar Agente'));
    await tester.pumpAndSettle();

    verify(() => caiService.agentesDisponibles('cai-001')).called(1);
    expect(find.text('Carlos Agente'), findsOneWidget);
  });

  testWidgets(
      'confirmar asignación llama incidenteService.asignar(), refresca la lista '
      'y muestra el snackbar verde', (tester) async {
    when(() => incidenteService.porCai())
        .thenAnswer((_) async => [_fake('i-001', EstadoIncidente.DERIVADO_A_CAI)]);
    when(() => caiService.agentesDisponibles('cai-001')).thenAnswer((_) async => [
          const AgenteDisponible(id: 'ag-001', nombre: 'Carlos Agente', estado: EstadoAgente.DISPONIBLE),
        ]);
    when(() => incidenteService.asignar('i-001')).thenAnswer((_) async {});

    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Asignar Agente'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirmar asignación'));
    await tester.pumpAndSettle();

    verify(() => incidenteService.asignar('i-001')).called(1);
    verify(() => incidenteService.porCai()).called(2); // carga inicial + refresco
    expect(find.text('Agente asignado exitosamente.'), findsOneWidget);
  });

  testWidgets('sin agentes disponibles: botón "Confirmar asignación" deshabilitado',
      (tester) async {
    when(() => incidenteService.porCai())
        .thenAnswer((_) async => [_fake('i-001', EstadoIncidente.DERIVADO_A_CAI)]);
    when(() => caiService.agentesDisponibles('cai-001')).thenAnswer((_) async => []);

    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Asignar Agente'));
    await tester.pumpAndSettle();

    expect(find.text('No hay agentes disponibles en este CAI en este momento.'),
        findsOneWidget);
    final boton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Confirmar asignación'),
    );
    expect(boton.onPressed, isNull);
  });

  testWidgets(
      'si falla la consulta de agentes (ApiException), muestra el aviso naranja '
      'pero el botón de asignación automática sigue habilitado', (tester) async {
    when(() => incidenteService.porCai())
        .thenAnswer((_) async => [_fake('i-001', EstadoIncidente.DERIVADO_A_CAI)]);
    when(() => caiService.agentesDisponibles('cai-001')).thenThrow(
      const ApiException(type: ApiExceptionType.timeout, message: 'Tiempo de espera agotado'),
    );

    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Asignar Agente'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No se pudo cargar la lista de agentes'), findsOneWidget);
    final boton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Confirmar asignación'),
    );
    expect(boton.onPressed, isNotNull);
  });

  testWidgets('botón "X" del sheet lo cierra sin llamar a asignar()', (tester) async {
    when(() => incidenteService.porCai())
        .thenAnswer((_) async => [_fake('i-001', EstadoIncidente.DERIVADO_A_CAI)]);
    when(() => caiService.agentesDisponibles('cai-001')).thenAnswer((_) async => []);

    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Asignar Agente'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Asignar agente'), findsNothing);
    verifyNever(() => incidenteService.asignar(any()));
  });

  testWidgets('tap en la card (fuera del botón) navega a DetalleIncidenteView',
      (tester) async {
    when(() => incidenteService.porCai())
        .thenAnswer((_) async => [_fake('i-001', EstadoIncidente.DERIVADO_A_CAI)]);

    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Robos o asaltos').hitTestable().first);
    await tester.pumpAndSettle();

    expect(find.text('detalle_incidente'), findsOneWidget);
  });

  testWidgets(
      'botón de logout muestra confirmación antes de cerrar sesión (fix hallazgo #2)',
      (tester) async {
    when(() => incidenteService.porCai()).thenAnswer((_) async => []);

    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();

    expect(find.text('¿Cerrar sesión?'), findsOneWidget);
    expect(sesion.isAuthenticated, isTrue);

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(sesion.isAuthenticated, isFalse);
    expect(find.text('role_selection'), findsOneWidget);
  });

  testWidgets('cancelar la confirmación de logout NO cierra la sesión',
      (tester) async {
    when(() => incidenteService.porCai()).thenAnswer((_) async => []);

    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(sesion.isAuthenticated, isTrue);
    expect(find.text('role_selection'), findsNothing);
  });

  // Épica 8, Bloque 2, ítem 4.
  testWidgets('el botón de logout expone tooltip "Cerrar sesión" (accesibilidad)',
      (tester) async {
    when(() => incidenteService.porCai()).thenAnswer((_) async => []);

    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();

    expect(find.byTooltip('Cerrar sesión'), findsOneWidget);
  });

  // Bloque 4 (Épica 8) — pantalla chica. Ya se encontró y corrigió un bug
  // real de este tipo en este mismo archivo (sheet de asignar agente sin
  // isScrollControlled) — este test cubre el caso con VARIOS agentes en
  // la lista, el escenario más exigente para el sheet.
  testWidgets('sheet "Asignar Agente" con varios agentes no desborda en '
      'pantalla chica (375x667)', (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    when(() => incidenteService.porCai())
        .thenAnswer((_) async => [_fake('i-001', EstadoIncidente.DERIVADO_A_CAI)]);
    when(() => caiService.agentesDisponibles('cai-001')).thenAnswer((_) async => [
          const AgenteDisponible(id: 'ag-001', nombre: 'Carlos Agente Uno', estado: EstadoAgente.DISPONIBLE),
          const AgenteDisponible(id: 'ag-002', nombre: 'Ana Agente Dos', estado: EstadoAgente.DISPONIBLE),
          const AgenteDisponible(id: 'ag-003', nombre: 'Pedro Agente Tres', estado: EstadoAgente.DISPONIBLE),
          const AgenteDisponible(id: 'ag-004', nombre: 'Luisa Agente Cuatro', estado: EstadoAgente.DISPONIBLE),
        ]);

    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Asignar Agente'));
    await tester.pumpAndSettle();

    expect(find.text('Carlos Agente Uno'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Bloque 4 (Épica 8) — nombre de agente extremadamente largo. El fix
  // (Expanded + TextOverflow.ellipsis en la fila del agente, ver
  // home_cai_view.dart) ya está aplicado; este test lo deja verificado
  // para que no se rompa sin querer en un cambio futuro.
  testWidgets('un nombre de agente muy largo se trunca (ellipsis), no desborda el Row',
      (tester) async {
    final nombreLargo =
        'Juan Carlos Alejandro de la Santísima Trinidad Rodríguez Pérez '
        'González Martínez'; // ~85 caracteres, muy por encima de un nombre real

    when(() => incidenteService.porCai())
        .thenAnswer((_) async => [_fake('i-001', EstadoIncidente.DERIVADO_A_CAI)]);
    when(() => caiService.agentesDisponibles('cai-001')).thenAnswer((_) async => [
          AgenteDisponible(id: 'ag-001', nombre: nombreLargo, estado: EstadoAgente.DISPONIBLE),
        ]);

    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Asignar Agente'));
    await tester.pumpAndSettle();

    // El texto completo SÍ está en el árbol de widgets (Text no lo corta
    // a nivel de string, solo visualmente vía overflow: ellipsis) — lo
    // que este test realmente verifica es que renderizar ese Text no
    // lance ninguna excepción de layout.
    expect(find.text(nombreLargo), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}