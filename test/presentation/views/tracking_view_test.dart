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
      'BUG DETECTADO: tras un fallo de carga, "Reintentar" NO vuelve a llamar '
      'consultar() — se queda en spinner infinito sin ninguna llamada de red',
      (tester) async {
    // _inicializar() solo asigna _incidente dentro del try exitoso (línea
    // ~76 de tracking_view.dart) — en la rama catch, _incidente queda
    // null. El botón "Reintentar" solo reintenta si `_incidente != null`
    // (línea ~187), guard que nunca se cumple después de un fallo
    // inicial. Este test documenta el comportamiento ACTUAL (buggy), no
    // el deseado — el fix correcto sería reintentar con el
    // `incidenteId` original (guardado en un campo de estado), no
    // depender de que `_incidente` ya se haya cargado con éxito antes.
    when(() => incidenteService.consultar('i-001'))
        .thenThrow(Exception('Sin conexión'));

    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reintentar'));
    await tester.pump();

    // Se queda mostrando el spinner para siempre — nunca vuelve a
    // renderizar el mensaje de error ni el botón, porque _inicializar()
    // nunca vuelve a ejecutarse.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    verify(() => incidenteService.consultar('i-001')).called(1); // NO 2 — este es el bug
  });
}