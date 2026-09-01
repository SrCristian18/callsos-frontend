import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:CallSos/core/app_routes.dart';
import 'package:CallSos/data/models/auditoria_incidente.dart';
import 'package:CallSos/data/models/auth_result.dart';
import 'package:CallSos/data/models/enums/estado_incidente.dart';
import 'package:CallSos/data/models/enums/rol.dart';
import 'package:CallSos/data/models/enums/tipo_incidente_enum.dart';
import 'package:CallSos/data/models/incidente.dart';
import 'package:CallSos/data/services/api_exception.dart';
import 'package:CallSos/data/services/auditoria_service.dart';
import 'package:CallSos/data/services/auth_service.dart';
import 'package:CallSos/data/services/incidente_service.dart';
import 'package:CallSos/data/services/secure_storage.dart';
import 'package:CallSos/data/services/stomp_service.dart';
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

/// EPIC-07 — mock del servicio de auditoría que consume la nueva pestaña
/// "Historial" (`Timeline`, ver `timeline.dart`).
class MockAuditoriaService extends Mock implements IAuditoriaService {}

/// FIX: `EtaWidget` ahora lee `IStompService` desde el Provider
/// (`context.read<IStompService>()`) en vez de instanciar `StompService`
/// real directamente — ver el docstring de `eta_widget.dart`. Este mock
/// es lo que hace posible sustituir esa conexión en el test de abajo sin
/// disparar un WebSocket real ni dejar un Timer pendiente tras el
/// dispose del árbol de widgets.
class MockStompService extends Mock implements IStompService {}

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
        {String? nombreCAI,
        String denuncianteId = 'den-001',
        String? agenteId}) =>
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
      agenteId: agenteId,
    );

void main() {
  late MockAuthService authService;
  late MockIncidenteService incidenteService;
  late MockAuditoriaService auditoriaService;
  late MockStompService stompService;
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

    // EPIC-07: stub por defecto — lista vacía. Los tests del bloque
    // "Historial" lo sobrescriben cuando necesitan datos/error
    // específicos. Sin este default, cualquier test que llegue a
    // construir la pestaña "Historial" (aunque no la esté probando a
    // propósito) fallaría con un MissingStubError.
    auditoriaService = MockAuditoriaService();
    when(() => auditoriaService.historial(any())).thenAnswer((_) async => []);

    // Stubs mínimos para que EtaWidget (si llega a montarse — solo
    // ocurre con DENUNCIANTE + AGENTE_EN_CAMINO) no reciba llamadas sin
    // estubear. conectar() nunca invoca onConnected/onError aquí — el
    // test de ETA no depende de llegar a estado "conectado", solo de
    // que el widget se construya sin lanzar una conexión WS real.
    stompService = MockStompService();
    when(() => stompService.conectar(
          onConnected: any(named: 'onConnected'),
          onError: any(named: 'onError'),
        )).thenAnswer((_) async {});
    when(() => stompService.desconectar()).thenAnswer((_) async {});
  });

  Widget appDePrueba({required String incidenteId}) {
    return MultiProvider(
      providers: [
        Provider<IIncidenteService>.value(value: incidenteService),
        Provider<IAuditoriaService>.value(value: auditoriaService),
        Provider<IStompService>.value(value: stompService),
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
            return Scaffold(
                body: Text('tracking:${args['incidenteId']}:${args['agenteId']}'));
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
      'DENUNCIANTE + AGENTE_EN_CAMINO: muestra el widget de ETA (Épica 7) '
      'en vez del antiguo botón "Ver agente en mapa"', (tester) async {
    await loguearComo('den-001', Rol.DENUNCIANTE);
    when(() => incidenteService.consultar('i-001'))
        .thenAnswer((_) async => _fake('i-001', EstadoIncidente.AGENTE_EN_CAMINO));

    await tester.pumpWidget(appDePrueba(incidenteId: 'i-001'));
    await tester.pumpAndSettle();

    expect(find.text('Tiempo estimado de llegada'), findsOneWidget);
    expect(find.textContaining('Ver agente en mapa'), findsNothing);

    verify(() => stompService.conectar(
          onConnected: any(named: 'onConnected'),
          onError: any(named: 'onError'),
        )).called(1);
  });

  testWidgets(
      'AGENTE + AGENTE_ASIGNADO: botón "Compartir mi ubicación" navega a '
      'Tracking con incidenteId y agenteId == actorId (Épica 7)',
      (tester) async {
    await loguearComo('ag-001', Rol.AGENTE);
    when(() => incidenteService.consultar('i-001'))
        .thenAnswer((_) async => _fake('i-001', EstadoIncidente.AGENTE_ASIGNADO));

    await tester.pumpWidget(appDePrueba(incidenteId: 'i-001'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Compartir mi ubicación'));
    await tester.pumpAndSettle();

    expect(find.text('tracking:i-001:ag-001'), findsOneWidget);
  });

  testWidgets(
      'OPERADOR_CAI + agente asignado + AGENTE_EN_CAMINO: botón "Ver ubicación '
      'del agente" navega a Tracking con el agenteId del incidente (Épica 7)',
      (tester) async {
    await loguearComo('cai-001', Rol.OPERADOR_CAI);
    when(() => incidenteService.consultar('i-001')).thenAnswer((_) async => _fake(
        'i-001', EstadoIncidente.AGENTE_EN_CAMINO,
        agenteId: 'ag-999'));

    await tester.pumpWidget(appDePrueba(incidenteId: 'i-001'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Ver ubicación del agente'));
    await tester.pumpAndSettle();

    expect(find.text('tracking:i-001:ag-999'), findsOneWidget);
  });

  testWidgets(
      'COMANDO en AGENTE_EN_CAMINO pero sin agenteId resuelto todavía: '
      'NO muestra "Ver ubicación del agente" (guarda defensiva)', (tester) async {
    await loguearComo('com-001', Rol.COMANDO);
    when(() => incidenteService.consultar('i-001')).thenAnswer(
        (_) async => _fake('i-001', EstadoIncidente.AGENTE_EN_CAMINO, agenteId: null));

    await tester.pumpWidget(appDePrueba(incidenteId: 'i-001'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Ver ubicación del agente'), findsNothing);
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

      // Defensivo: si el catálogo de tipos crece, o el sheet vuelve a
      // necesitar scroll interno por cualquier motivo, ensureVisible()
      // scrollea el ListView hasta el ítem antes de aserir/tocar sobre
      // él — evita que este test vuelva a romperse por un ítem fuera
      // del viewport (la causa raíz real ya se corrigió en
      // selector_tipo_incidente.dart con isScrollControlled: true).
      final finderAtentados = find.text('Atentados');
      await tester.ensureVisible(finderAtentados);
      await tester.pumpAndSettle();

      expect(find.text('Riñas o peleas'), findsOneWidget);
      expect(finderAtentados, findsOneWidget);
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

      final finderRinas = find.text('Riñas o peleas');
      await tester.ensureVisible(finderRinas);
      await tester.pumpAndSettle();
      await tester.tap(finderRinas);
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
      final finderRinas403 = find.text('Riñas o peleas');
      await tester.ensureVisible(finderRinas403);
      await tester.pumpAndSettle();
      await tester.tap(finderRinas403);
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

  // EPIC-07 — pestaña "Historial" (Timeline de auditoría).
  group('Historial (EPIC-07)', () {
    testWidgets('mientras carga el incidente, no muestra TabBar todavía '
        '(sin bottom en el AppBar)', (tester) async {
      await loguearComo('com-001', Rol.COMANDO);
      when(() => incidenteService.consultar('i-001')).thenAnswer(
        (_) => Future.delayed(
            const Duration(milliseconds: 500),
            () => _fake('i-001', EstadoIncidente.CREADO)),
      );

      await tester.pumpWidget(appDePrueba(incidenteId: 'i-001'));
      await tester.pump();

      expect(find.text('Historial'), findsNothing);

      await tester.pumpAndSettle();
    });

    testWidgets('una vez cargado el incidente, aparecen las pestañas '
        '"Detalle" y "Historial"', (tester) async {
      await loguearComo('com-001', Rol.COMANDO);
      when(() => incidenteService.consultar('i-001'))
          .thenAnswer((_) async => _fake('i-001', EstadoIncidente.CREADO));

      await tester.pumpWidget(appDePrueba(incidenteId: 'i-001'));
      await tester.pumpAndSettle();

      expect(find.text('Detalle'), findsOneWidget);
      expect(find.text('Historial'), findsOneWidget);
    });

    testWidgets('tocar "Historial" muestra los eventos de auditoría del '
        'incidente (GET /auditoria/incidente/{id})', (tester) async {
      await loguearComo('com-001', Rol.COMANDO);
      when(() => incidenteService.consultar('i-001'))
          .thenAnswer((_) async => _fake('i-001', EstadoIncidente.DERIVADO_A_CAI));
      when(() => auditoriaService.historial('i-001')).thenAnswer((_) async => [
            AuditoriaIncidente(
              incidenteId: 'i-001',
              estadoNuevo: EstadoIncidente.CREADO,
              actorId: 'den-001',
              actorRol: 'DENUNCIANTE',
              timestamp: DateTime(2026, 6, 14, 10, 0),
              detalle: 'Incidente creado.',
            ),
            AuditoriaIncidente(
              incidenteId: 'i-001',
              estadoAnterior: EstadoIncidente.CREADO,
              estadoNuevo: EstadoIncidente.DERIVADO_A_CAI,
              actorId: 'com-001',
              actorRol: 'COMANDO',
              timestamp: DateTime(2026, 6, 14, 10, 5),
              detalle: 'Derivado al CAI más cercano.',
            ),
          ]);

      await tester.pumpWidget(appDePrueba(incidenteId: 'i-001'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Historial'));
      await tester.pumpAndSettle();

      expect(find.text('Incidente creado.'), findsOneWidget);
      expect(find.text('Derivado al CAI más cercano.'), findsOneWidget);
      verify(() => auditoriaService.historial('i-001')).called(1);
    });

    testWidgets('sin eventos todavía, la pestaña Historial muestra el '
        'estado vacío', (tester) async {
      await loguearComo('com-001', Rol.COMANDO);
      when(() => incidenteService.consultar('i-001'))
          .thenAnswer((_) async => _fake('i-001', EstadoIncidente.CREADO));
      when(() => auditoriaService.historial('i-001')).thenAnswer((_) async => []);

      await tester.pumpWidget(appDePrueba(incidenteId: 'i-001'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Historial'));
      await tester.pumpAndSettle();

      expect(find.text('Todavía no hay eventos registrados.'), findsOneWidget);
    });

    testWidgets('si el backend rechaza (403 — el actor no está autorizado '
        'sobre este incidente), la pestaña Historial muestra el error, sin '
        'afectar la pestaña Detalle', (tester) async {
      await loguearComo('ag-999', Rol.AGENTE);
      when(() => incidenteService.consultar('i-001')).thenAnswer(
          (_) async => _fake('i-001', EstadoIncidente.AGENTE_ASIGNADO));
      when(() => auditoriaService.historial('i-001')).thenThrow(
        const ApiException(
          type: ApiExceptionType.forbidden,
          message:
              'No tiene autorización para consultar la auditoría de este incidente.',
        ),
      );

      await tester.pumpWidget(appDePrueba(incidenteId: 'i-001'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Historial'));
      await tester.pumpAndSettle();

      expect(
        find.text('No tiene autorización para consultar la auditoría de este incidente.'),
        findsOneWidget,
      );

      // La pestaña "Detalle" sigue intacta — el 403 de auditoría no
      // afecta el resto de la vista (fuentes de datos independientes).
      await tester.tap(find.text('Detalle'));
      await tester.pumpAndSettle();
      expect(find.text('Robos o asaltos'), findsWidgets);
    });

    testWidgets('los 4 roles pueden abrir la pestaña Historial — el '
        'filtrado real de autorización vive en el backend, no acá',
        (tester) async {
      for (final entry in {
        'den-001': Rol.DENUNCIANTE,
        'ag-001': Rol.AGENTE,
        'cai-001': Rol.OPERADOR_CAI,
        'com-001': Rol.COMANDO,
      }.entries) {
        await loguearComo(entry.key, entry.value);
        when(() => incidenteService.consultar('i-001'))
            .thenAnswer((_) async => _fake('i-001', EstadoIncidente.CREADO));
        when(() => auditoriaService.historial('i-001')).thenAnswer((_) async => [
              AuditoriaIncidente(
                incidenteId: 'i-001',
                estadoNuevo: EstadoIncidente.CREADO,
                actorId: entry.key,
                actorRol: entry.value.name,
                timestamp: DateTime(2026, 6, 14, 10, 0),
                detalle: 'Incidente creado.',
              ),
            ]);

        await tester.pumpWidget(appDePrueba(incidenteId: 'i-001'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Historial'));
        await tester.pumpAndSettle();

        expect(find.text('Incidente creado.'), findsOneWidget,
            reason: 'Falló para el rol ${entry.value.name}');

        // Limpieza entre iteraciones del loop.
        await tester.pumpWidget(const SizedBox());
        await sesion.logout();
      }
    });
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