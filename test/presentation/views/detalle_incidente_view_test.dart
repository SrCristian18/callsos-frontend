import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:CallSos/core/app_routes.dart';
import 'package:CallSos/data/models/auth_result.dart';
import 'package:CallSos/data/models/enums/estado_incidente.dart';
import 'package:CallSos/data/models/enums/rol.dart';
import 'package:CallSos/data/models/enums/tipo_incidente_enum.dart';
import 'package:CallSos/data/models/incidente.dart';
import 'package:CallSos/data/services/api_exception.dart';
import 'package:CallSos/data/services/auth_service.dart';
import 'package:CallSos/data/services/incidente_service.dart';
import 'package:CallSos/data/services/secure_storage.dart';
import 'package:CallSos/presentation/viewmodels/sesion_viewmodel.dart';
import 'package:CallSos/presentation/views/detalle_incidente_view.dart';

/// Épica 5 (ruta técnica) — widget test de DetalleIncidenteView.
///
/// A diferencia de las "home", esta vista no tiene un ChangeNotifier
/// propio — el estado (loading/error/incidente/enProceso) vive en el
/// State del StatefulWidget. Recibe `incidenteId` por argumentos de ruta
/// (`ModalRoute.of(context)?.settings.arguments`), así que
/// `appDePrueba()` usa `onGenerateRoute` para controlar esos argumentos
/// de forma determinística en cada test.
///
/// El cableado de botones contextuales depende de la combinación
/// (rol de la sesión, estado del incidente) — cada test fija ambos
/// explícitamente para aislar una única combinación por vez.
class MockAuthService extends Mock implements IAuthService {}

class MockIncidenteService extends Mock implements IIncidenteService {}

class FakeSecureStorage implements ISecureStorage {
  final Map<String, String> _datos = {};
  @override
  Future<String?> read(String key) async => _datos[key];
  @override
  Future<void> write(String key, String value) async => _datos[key] = value;
  @override
  Future<void> delete(String key) async => _datos.remove(key);
}

Incidente _fake(String id, EstadoIncidente estado,
        {String? nombreCAI, String denuncianteId = 'den-001'}) =>
    Incidente(
      id: id,
      fechaHora: DateTime(2026, 6, 14, 10, 30),
      tipo: TipoIncidenteEnum.ROBOS_O_ASALTOS,
      descripcion: 'Me están robando',
      estado: estado,
      latitud: 10.391,
      longitud: -75.4794,
      denuncianteId: denuncianteId,
      nombreCAI: nombreCAI,
    );

void main() {
  late MockAuthService authService;
  late MockIncidenteService incidenteService;
  late SesionViewModel sesion;

  // Épica 6: `any()` para TipoIncidenteEnum (verifyNever en el test de
  // "cerrar el selector sin elegir") requiere un fallback registrado —
  // mismo patrón que home_denunciante_view_test.dart y
  // crear_incidente_viewmodel_test.dart.
  setUpAll(() {
    registerFallbackValue(TipoIncidenteEnum.ROBOS_O_ASALTOS);
  });

  Future<void> loguearComo(String actorId, Rol rol) async {
    when(() => authService.login(username: actorId, password: '1234')).thenAnswer(
      (_) async => AuthResult(token: 'jwt-$actorId', actorId: actorId, rol: rol, nombre: 'Test'),
    );
    await sesion.login(username: actorId, password: '1234');
  }

  setUp(() {
    authService = MockAuthService();
    incidenteService = MockIncidenteService();
    sesion = SesionViewModel(authService: authService, storage: FakeSecureStorage());
  });

  Widget appDePrueba({required String incidenteId}) {
    return MultiProvider(
      providers: [
        Provider<IIncidenteService>.value(value: incidenteService),
        ChangeNotifierProvider<SesionViewModel>.value(value: sesion),
      ],
      child: MaterialApp(
        onGenerateRoute: (_) => MaterialPageRoute(
          builder: (_) => const DetalleIncidenteView(),
          settings: RouteSettings(arguments: {'incidenteId': incidenteId}),
        ),
        routes: {
          AppRoutes.tracking: (ctx) {
            final args = ModalRoute.of(ctx)!.settings.arguments as Map;
            return Scaffold(body: Text('tracking:${args['incidenteId']}'));
          },
          AppRoutes.reporteHallazgos: (ctx) {
            final args = ModalRoute.of(ctx)!.settings.arguments as Map;
            return Scaffold(body: Text('reporte_hallazgos:${args['incidenteId']}'));
          },
        },
      ),
    );
  }

  testWidgets('carga /incidentes/{id} y muestra tipo, estado, fecha, coordenadas y CAI',
      (tester) async {
    await loguearComo('com-001', Rol.COMANDO);
    when(() => incidenteService.consultar('i-001')).thenAnswer(
        (_) async => _fake('i-001', EstadoIncidente.DERIVADO_A_CAI, nombreCAI: 'CAI San José'));

    await tester.pumpWidget(appDePrueba(incidenteId: 'i-001'));
    await tester.pumpAndSettle();

    expect(find.text('Robos o asaltos'), findsWidgets); // título del AppBar + card
    expect(find.text('Me están robando'), findsOneWidget);
    expect(find.text('14/06/2026  10:30'), findsOneWidget);
    expect(find.text('10.39100, -75.47940'), findsOneWidget);
    expect(find.text('CAI San José'), findsOneWidget);
  });

  testWidgets('sin CAI asignado, no muestra la fila "CAI asignado"', (tester) async {
    await loguearComo('com-001', Rol.COMANDO);
    when(() => incidenteService.consultar('i-001'))
        .thenAnswer((_) async => _fake('i-001', EstadoIncidente.CREADO));

    await tester.pumpWidget(appDePrueba(incidenteId: 'i-001'));
    await tester.pumpAndSettle();

    expect(find.text('CAI asignado'), findsNothing);
  });

  testWidgets('error de carga (ApiException) muestra el mensaje y "Reintentar" recarga',
      (tester) async {
    await loguearComo('com-001', Rol.COMANDO);
    when(() => incidenteService.consultar('i-404')).thenThrow(
      const ApiException(type: ApiExceptionType.notFound, message: 'Incidente no encontrado'),
    );

    await tester.pumpWidget(appDePrueba(incidenteId: 'i-404'));
    await tester.pumpAndSettle();

    expect(find.text('Incidente no encontrado'), findsOneWidget);

    when(() => incidenteService.consultar('i-404'))
        .thenAnswer((_) async => _fake('i-404', EstadoIncidente.CREADO));
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Incidente no encontrado'), findsNothing);
    verify(() => incidenteService.consultar('i-404')).called(2);
  });

  testWidgets(
      'DENUNCIANTE + AGENTE_EN_CAMINO: botón "Ver agente en mapa" navega a Tracking '
      'con el incidenteId', (tester) async {
    await loguearComo('den-001', Rol.DENUNCIANTE);
    when(() => incidenteService.consultar('i-001'))
        .thenAnswer((_) async => _fake('i-001', EstadoIncidente.AGENTE_EN_CAMINO));

    await tester.pumpWidget(appDePrueba(incidenteId: 'i-001'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Ver agente en mapa'));
    await tester.pumpAndSettle();

    expect(find.text('tracking:i-001'), findsOneWidget);
  });

  testWidgets('AGENTE + AGENTE_ASIGNADO: "Ir en camino" llama enCamino(), snackbar y refresca',
      (tester) async {
    await loguearComo('ag-001', Rol.AGENTE);
    when(() => incidenteService.consultar('i-001'))
        .thenAnswer((_) async => _fake('i-001', EstadoIncidente.AGENTE_ASIGNADO));
    when(() => incidenteService.enCamino('i-001')).thenAnswer((_) async {});

    await tester.pumpWidget(appDePrueba(incidenteId: 'i-001'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Ir en camino'));
    await tester.pumpAndSettle();

    verify(() => incidenteService.enCamino('i-001')).called(1);
    verify(() => incidenteService.consultar('i-001')).called(2); // carga inicial + refresco
    expect(find.text('Marcaste que vas en camino.'), findsOneWidget);
  });

  testWidgets(
      'AGENTE + AGENTE_EN_CAMINO: "Llegué — Iniciar atención" llama atender()',
      (tester) async {
    await loguearComo('ag-001', Rol.AGENTE);
    when(() => incidenteService.consultar('i-001'))
        .thenAnswer((_) async => _fake('i-001', EstadoIncidente.AGENTE_EN_CAMINO));
    when(() => incidenteService.atender('i-001')).thenAnswer((_) async {});

    await tester.pumpWidget(appDePrueba(incidenteId: 'i-001'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Llegué'));
    await tester.pumpAndSettle();

    verify(() => incidenteService.atender('i-001')).called(1);
  });

  testWidgets(
      'AGENTE + EN_ATENCION: "Finalizar y reportar hallazgos" navega a ReporteHallazgos '
      'sin llamar evaluar() directamente (lo hace el POST de hallazgos)', (tester) async {
    await loguearComo('ag-001', Rol.AGENTE);
    when(() => incidenteService.consultar('i-001'))
        .thenAnswer((_) async => _fake('i-001', EstadoIncidente.EN_ATENCION));

    await tester.pumpWidget(appDePrueba(incidenteId: 'i-001'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Finalizar y reportar hallazgos'));
    await tester.pumpAndSettle();

    expect(find.text('reporte_hallazgos:i-001'), findsOneWidget);
    verifyNever(() => incidenteService.evaluar(any()));
  });

  testWidgets('DENUNCIANTE + incidente activo: muestra y usa "Cancelar emergencia"',
      (tester) async {
    await loguearComo('den-001', Rol.DENUNCIANTE);
    when(() => incidenteService.consultar('i-001'))
        .thenAnswer((_) async => _fake('i-001', EstadoIncidente.CREADO));
    when(() => incidenteService.cancelar('i-001')).thenAnswer((_) async {});

    await tester.pumpWidget(appDePrueba(incidenteId: 'i-001'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancelar emergencia'));
    await tester.pumpAndSettle();

    verify(() => incidenteService.cancelar('i-001')).called(1);
    expect(find.text('Emergencia cancelada.'), findsOneWidget);
  });

  // Épica 6 — actualizar tipo de incidente (denunciante dueño).
  group('Actualizar tipo de incidente (Épica 6)', () {
    testWidgets('DENUNCIANTE dueño + activo: muestra el botón "Actualizar tipo de incidente"',
        (tester) async {
      await loguearComo('den-001', Rol.DENUNCIANTE);
      when(() => incidenteService.consultar('i-001'))
          .thenAnswer((_) async => _fake('i-001', EstadoIncidente.CREADO));

      await tester.pumpWidget(appDePrueba(incidenteId: 'i-001'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Actualizar tipo de incidente'), findsOneWidget);
    });

    testWidgets(
        'DENUNCIANTE NO dueño (otro denunciante): NO muestra el botón, aunque el incidente esté activo',
        (tester) async {
      await loguearComo('den-999-otro', Rol.DENUNCIANTE);
      when(() => incidenteService.consultar('i-001')).thenAnswer((_) async =>
          _fake('i-001', EstadoIncidente.CREADO, denuncianteId: 'den-001'));

      await tester.pumpWidget(appDePrueba(incidenteId: 'i-001'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Actualizar tipo de incidente'), findsNothing);
    });

    testWidgets('DENUNCIANTE dueño + FINALIZADO (no activo): NO muestra el botón',
        (tester) async {
      await loguearComo('den-001', Rol.DENUNCIANTE);
      when(() => incidenteService.consultar('i-001'))
          .thenAnswer((_) async => _fake('i-001', EstadoIncidente.FINALIZADO));

      await tester.pumpWidget(appDePrueba(incidenteId: 'i-001'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Actualizar tipo de incidente'), findsNothing);
    });

    testWidgets('rol distinto de DENUNCIANTE (ej. AGENTE): NO muestra el botón',
        (tester) async {
      await loguearComo('ag-001', Rol.AGENTE);
      when(() => incidenteService.consultar('i-001')).thenAnswer((_) async =>
          _fake('i-001', EstadoIncidente.AGENTE_ASIGNADO, denuncianteId: 'den-001'));

      await tester.pumpWidget(appDePrueba(incidenteId: 'i-001'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Actualizar tipo de incidente'), findsNothing);
    });

    testWidgets(
        'tocar el botón abre el selector sin el tipo actual (ROBOS_O_ASALTOS) entre las opciones',
        (tester) async {
      await loguearComo('den-001', Rol.DENUNCIANTE);
      when(() => incidenteService.consultar('i-001'))
          .thenAnswer((_) async => _fake('i-001', EstadoIncidente.CREADO));

      await tester.pumpWidget(appDePrueba(incidenteId: 'i-001'));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Actualizar tipo de incidente'));
      await tester.pumpAndSettle();

      expect(find.text('Riñas o peleas'), findsOneWidget);
      expect(find.text('Atentados'), findsOneWidget);
      // El tipo actual del incidente (Robos o asaltos) no debe ofrecerse
      // como opción — aparece una sola vez, en el AppBar/card, no en la lista.
      expect(find.text('Robos o asaltos'), findsWidgets);
      expect(find.byType(ListTile), findsNWidgets(6)); // 7 tipos - 1 (el actual)
    });

    testWidgets(
        'elegir un tipo en el selector llama actualizarTipo(), muestra snackbar y refresca',
        (tester) async {
      await loguearComo('den-001', Rol.DENUNCIANTE);
      when(() => incidenteService.consultar('i-001'))
          .thenAnswer((_) async => _fake('i-001', EstadoIncidente.CREADO));
      when(() => incidenteService.actualizarTipo('i-001', TipoIncidenteEnum.RINAS_O_PELEAS))
          .thenAnswer((_) async {});

      await tester.pumpWidget(appDePrueba(incidenteId: 'i-001'));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Actualizar tipo de incidente'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Riñas o peleas'));
      await tester.pumpAndSettle();

      verify(() => incidenteService.actualizarTipo('i-001', TipoIncidenteEnum.RINAS_O_PELEAS))
          .called(1);
      verify(() => incidenteService.consultar('i-001')).called(2); // carga inicial + refresco
      expect(find.text('Tipo de incidente actualizado.'), findsOneWidget);
    });

    testWidgets('cerrar el selector sin elegir (deslizar hacia abajo) NO llama actualizarTipo',
        (tester) async {
      await loguearComo('den-001', Rol.DENUNCIANTE);
      when(() => incidenteService.consultar('i-001'))
          .thenAnswer((_) async => _fake('i-001', EstadoIncidente.CREADO));

      await tester.pumpWidget(appDePrueba(incidenteId: 'i-001'));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Actualizar tipo de incidente'));
      await tester.pumpAndSettle();

      // Cerrar tocando fuera del modal (barrera del bottom sheet).
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      verifyNever(() => incidenteService.actualizarTipo(any(), any()));
    });

    testWidgets(
        'ApiException 403 (no dueño, verificado server-side) muestra el error sin romper la vista',
        (tester) async {
      await loguearComo('den-001', Rol.DENUNCIANTE);
      when(() => incidenteService.consultar('i-001'))
          .thenAnswer((_) async => _fake('i-001', EstadoIncidente.CREADO));
      when(() => incidenteService.actualizarTipo('i-001', TipoIncidenteEnum.RINAS_O_PELEAS))
          .thenThrow(const ApiException(
        type: ApiExceptionType.forbidden,
        statusCode: 403,
        message: 'El denunciante autenticado no es el dueño de este incidente.',
      ));

      await tester.pumpWidget(appDePrueba(incidenteId: 'i-001'));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Actualizar tipo de incidente'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Riñas o peleas'));
      await tester.pumpAndSettle();

      expect(find.text('El denunciante autenticado no es el dueño de este incidente.'),
          findsOneWidget);
    });
  });

  testWidgets('incidente FINALIZADO (estado terminal): no muestra ningún botón de acción',
      (tester) async {
    await loguearComo('ag-001', Rol.AGENTE);
    when(() => incidenteService.consultar('i-001'))
        .thenAnswer((_) async => _fake('i-001', EstadoIncidente.FINALIZADO));

    await tester.pumpWidget(appDePrueba(incidenteId: 'i-001'));
    await tester.pumpAndSettle();

    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('botón de refrescar en el AppBar vuelve a llamar consultar()', (tester) async {
    await loguearComo('com-001', Rol.COMANDO);
    when(() => incidenteService.consultar('i-001'))
        .thenAnswer((_) async => _fake('i-001', EstadoIncidente.CREADO));

    await tester.pumpWidget(appDePrueba(incidenteId: 'i-001'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    verify(() => incidenteService.consultar('i-001')).called(2);
  });

  // Bloque 4 (Épica 8) — pantalla chica + texto largo.
  group('Responsive', () {
    testWidgets('no desborda en pantalla chica (375x667) con todos los '
        'bloques visibles (CAI, coordenadas, botón de acción)', (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await loguearComo('com-001', Rol.COMANDO);
      when(() => incidenteService.consultar('i-001')).thenAnswer((_) async =>
          _fake('i-001', EstadoIncidente.DERIVADO_A_CAI, nombreCAI: 'CAI San José'));

      await tester.pumpWidget(appDePrueba(incidenteId: 'i-001'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('no desborda con una descripción de ~200 caracteres', (tester) async {
      await loguearComo('ag-001', Rol.AGENTE);
      final descripcionLarga = 'Se reporta una situación de robo en la vía '
          'pública, presuntamente con arma blanca, el sujeto huyó en '
          'dirección al norte por la carrera principal, se solicita '
          'atención urgente ya que hay varios testigos presentes en el '
          'lugar de los hechos.'; // ~230 caracteres
      when(() => incidenteService.consultar('i-001')).thenAnswer((_) async => Incidente(
            id: 'i-001',
            fechaHora: DateTime(2026, 6, 14, 10, 30),
            tipo: TipoIncidenteEnum.ROBOS_O_ASALTOS,
            descripcion: descripcionLarga,
            estado: EstadoIncidente.AGENTE_ASIGNADO,
            latitud: 10.391,
            longitud: -75.4794,
            denuncianteId: 'den-001',
          ));

      await tester.pumpWidget(appDePrueba(incidenteId: 'i-001'));
      await tester.pumpAndSettle();

      expect(find.textContaining('varios testigos presentes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}