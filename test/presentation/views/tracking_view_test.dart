import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:CallSos/data/models/auth_result.dart';
import 'package:CallSos/data/models/enums/rol.dart';
import 'package:CallSos/data/services/auth_service.dart';
import 'package:CallSos/data/services/geolocalizacion_service.dart';
import 'package:CallSos/data/services/incidente_service.dart';
import 'package:CallSos/data/services/secure_storage.dart';
import 'package:CallSos/data/services/stomp_service.dart';
import 'package:CallSos/presentation/viewmodels/sesion_viewmodel.dart';
import 'package:CallSos/presentation/views/tracking_view.dart';

/// Épica 5 (ruta técnica) — widget test de TrackingView.
///
/// FIX: `_TrackingViewState.initState()` ahora lee `IStompService` desde
/// el Provider (`context.read<IStompService>()`) en vez de instanciar
/// `StompService` real directamente — mismo fix aplicado a `EtaWidget`
/// (ver su docstring). El comentario original de este archivo describía
/// esto como una limitación conocida sin punto de inyección; ese punto
/// de inyección ahora existe, vía `Provider<IStompService>.value(...)`
/// en `appDePrueba()` (mismo patrón que `IIncidenteService`,
/// `IGeolocalizacionService`, etc.).
///
/// ALCANCE TODAVÍA LIMITADO: el desbloqueo de arriba resuelve el riesgo
/// de Timers/WebSocket real colgando el test runner, pero los tests de
/// ESTE archivo siguen sin ejercitar el camino feliz completo (mapa +
/// marcadores + posición en tiempo real) — eso ya está cubierto
/// exhaustivamente en `tracking_viewmodel_test.dart` (que inyecta
/// `IStompService` directamente en `TrackingViewModel`, sin pasar por
/// widgets). Ampliar la cobertura de ESTE archivo al camino feliz
/// (`FlutterMap`, marcadores, `_ConexionIndicador`) queda como trabajo
/// futuro — no forma parte de este fix.
///
/// Épica 7: los argumentos de ruta ahora requieren `agenteId` además de
/// `incidenteId` — sin él, la vista muestra un error dedicado y NUNCA
/// llama a `consultar()` (ver el test específico para ese caso).
class MockAuthService extends Mock implements IAuthService {}

class MockIncidenteService extends Mock implements IIncidenteService {}

class MockGeolocalizacionService extends Mock implements IGeolocalizacionService {}

/// Mismo mock/patrón que `detalle_incidente_view_test.dart` — ver ahí
/// para el detalle completo del fix que lo hizo necesario.
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

void main() {
  late MockAuthService authService;
  late MockIncidenteService incidenteService;
  late MockGeolocalizacionService geoService;
  late MockStompService stompService;
  late SesionViewModel sesion;

  setUp(() async {
    authService = MockAuthService();
    incidenteService = MockIncidenteService();
    geoService = MockGeolocalizacionService();
    sesion = SesionViewModel(authService: authService, storage: FakeSecureStorage());

    // Necesario ahora que TrackingView lee IStompService desde el
    // Provider en initState() — se ejecuta en TODOS los tests de este
    // archivo (aunque ninguno llegue a _vm.iniciar(), initState() sí
    // corre siempre al montar el widget). conectar()/desconectar() no
    // necesitan más comportamiento que "no lanzar" para los tests
    // actuales (que nunca llegan a invocarlos de verdad).
    stompService = MockStompService();
    when(() => stompService.conectar(
          onConnected: any(named: 'onConnected'),
          onError: any(named: 'onError'),
        )).thenAnswer((_) async {});
    when(() => stompService.desconectar()).thenAnswer((_) async {});

    // Épica 7: DENUNCIANTE ya no accede a TrackingView (bloqueado por
    // RouteGuard antes de llegar acá) — se loguea como AGENTE para que
    // los datos de sesión sean consistentes con quién realmente puede
    // abrir esta vista (aunque, como documenta el header del archivo,
    // ningún test de acá llega a usar el rol dentro de _vm.iniciar()).
    when(() => authService.login(username: 'ag-001', password: '1234')).thenAnswer(
      (_) async => const AuthResult(
          token: 'jwt-ag', actorId: 'ag-001', rol: Rol.AGENTE, nombre: 'Pedro'),
    );
    await sesion.login(username: 'ag-001', password: '1234');
  });

  Widget appDePrueba() {
    return MultiProvider(
      providers: [
        Provider<IIncidenteService>.value(value: incidenteService),
        Provider<IGeolocalizacionService>.value(value: geoService),
        Provider<IStompService>.value(value: stompService),
        ChangeNotifierProvider<SesionViewModel>.value(value: sesion),
      ],
      child: MaterialApp(
        onGenerateRoute: (_) => MaterialPageRoute(
          builder: (_) => const TrackingView(),
          settings: const RouteSettings(
            // Épica 7: agenteId ahora es requerido — sin él, la vista
            // muestra el error de "no se pudo determinar el agente" y
            // NUNCA llama a consultar() (ver test dedicado más abajo).
            arguments: {'incidenteId': 'i-001', 'agenteId': 'ag-001'},
          ),
        ),
      ),
    );
  }

  testWidgets('muestra el spinner de carga mientras consultar() está pendiente',
      (tester) async {
    final completer = Completer<void>();
    when(() => incidenteService.consultar('i-001'))
        .thenAnswer((_) => completer.future.then((_) => throw Exception('no llega aquí')));

    await tester.pumpWidget(appDePrueba());
    await tester.pump(); // un frame — consultar() sigue pendiente, sin resolver

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Seguimiento en tiempo real'), findsOneWidget);

    // Limpieza: completar el future pendiente para no dejar un timer/Future
    // colgando entre tests (el error se descarta, cae en el catch de
    // _inicializar y NO llega a _vm.iniciar() — ver docstring del archivo).
    completer.completeError(Exception('cleanup'));
    await tester.pumpAndSettle();
  });

  testWidgets(
      'error al cargar el incidente muestra el mensaje y "Reintentar" — '
      'NUNCA llega a iniciar tracking (STOMP)', (tester) async {
    when(() => incidenteService.consultar('i-001'))
        .thenThrow(Exception('Sin conexión'));

    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();

    expect(find.text('No se pudo cargar el incidente.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    // Si el flujo hubiera avanzado a _vm.iniciar(), consultar() no se
    // habría llamado de nuevo todavía, pero SÍ habría un mapa en pantalla
    // (_buildBody solo muestra el error, nunca el FlutterMap) — este
    // assert confirma que efectivamente nos quedamos en la rama de error.
    expect(find.text('Seguimiento en tiempo real'), findsOneWidget);
  });

  testWidgets(
      'FIX VERIFICADO: "Reintentar" vuelve a llamar consultar() con el mismo '
      'incidenteId y, si vuelve a fallar, muestra el error de nuevo (no spinner infinito)',
      (tester) async {
    // Antes del fix, _inicializar() solo asignaba _incidente dentro del
    // try exitoso (línea ~76 de tracking_view.dart) — en la rama catch,
    // _incidente quedaba null, y el guard de "Reintentar" (`_incidente
    // != null`) nunca se cumplía tras un fallo inicial: el usuario
    // quedaba con el spinner para siempre, sin ninguna llamada de red
    // nueva. El fix guarda el incidenteId original en `_incidenteId`
    // (set en didChangeDependencies, independiente de si consultar()
    // tuvo éxito) y usa ESE campo para reintentar.
    when(() => incidenteService.consultar('i-001'))
        .thenThrow(Exception('Sin conexión'));

    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();

    expect(find.text('No se pudo cargar el incidente.'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    // FIX (bug real de este test, diagnosticado en Bloque 4 con
    // debugPrint temporales): a diferencia de lo que asumía el
    // comentario original de este test, `verify(...).called(n)` en
    // mocktail SÍ consume/resetea el conteo de invocaciones ya
    // verificadas — no es un contador acumulado independiente de
    // cuántas veces se llamó a verify() antes. Por eso un
    // `verify(...).called(1)` a mitad de este test (justo después de la
    // carga inicial) dejaba el conteo en 0, y el único `.called(2)` de
    // más abajo en realidad medía solo la llamada del reintento (1), no
    // el total (2) — de ahí el "Expected: 2, Actual: 1" real. El fix es
    // el mismo patrón que ya usan sin problema el test
    // "se puede reintentar más de una vez seguida..." (más abajo en
    // este archivo) y el equivalente en detalle_incidente_view_test.dart:
    // UN SOLO verify() al final, nunca uno intermedio.
    verify(() => incidenteService.consultar('i-001')).called(2);

    // El mock sigue fallando, así que debe volver a mostrar el error
    // (no quedarse pegado en el spinner) — prueba que el ciclo completo
    // carga -> error -> reintentar -> carga -> error es sano y repetible.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('No se pudo cargar el incidente.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets(
      'se puede reintentar más de una vez seguida sin quedar en un estado inconsistente',
      (tester) async {
    when(() => incidenteService.consultar('i-001'))
        .thenThrow(Exception('Sin conexión'));

    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    // 1 carga inicial + 2 reintentos = 3 llamadas totales.
    verify(() => incidenteService.consultar('i-001')).called(3);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  // Bloque 4 (Épica 8) — pantalla chica. Limitado a los estados de carga/
  // error por la misma razón documentada arriba: no podemos dejar que
  // _inicializar() llegue a _vm.iniciar() (STOMP real) en un test.
  testWidgets('estado de error no desborda en pantalla chica (375x667)',
      (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    when(() => incidenteService.consultar('i-001'))
        .thenThrow(Exception('Sin conexión'));

    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();

    expect(find.text('No se pudo cargar el incidente.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('Épica 7 — agenteId requerido en los argumentos de ruta', () {
    testWidgets(
        'sin agenteId en los argumentos, muestra un error dedicado y NUNCA llama a consultar()',
        (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<IIncidenteService>.value(value: incidenteService),
            Provider<IGeolocalizacionService>.value(value: geoService),
            Provider<IStompService>.value(value: stompService),
            ChangeNotifierProvider<SesionViewModel>.value(value: sesion),
          ],
          child: MaterialApp(
            onGenerateRoute: (_) => MaterialPageRoute(
              builder: (_) => const TrackingView(),
              // Solo incidenteId — sin agenteId (ej. link viejo/mal formado).
              settings:
                  const RouteSettings(arguments: {'incidenteId': 'i-001'}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No se pudo determinar el agente a seguir.'),
          findsOneWidget);
      verifyNever(() => incidenteService.consultar(any()));
    });
  });
}