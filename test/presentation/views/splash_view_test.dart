import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:CallSos/core/app_routes.dart';
import 'package:CallSos/data/models/enums/rol.dart';
import 'package:CallSos/data/services/auth_service.dart';
import 'package:CallSos/data/services/secure_storage.dart';
import 'package:CallSos/presentation/viewmodels/sesion_viewmodel.dart';
import 'package:CallSos/presentation/views/splash_view.dart';

class MockAuthService extends Mock implements IAuthService {}

/// Mismo fake in-memory usado en sesion_viewmodel_test.dart.
class FakeSecureStorage implements ISecureStorage {
  final Map<String, String> _datos = {};

  @override
  Future<String?> read(String key) async => _datos[key];

  @override
  Future<void> write(String key, String value) async => _datos[key] = value;

  @override
  Future<void> delete(String key) async => _datos.remove(key);
}

String _crearJwt(Map<String, dynamic> payload) {
  String segmento(Map<String, dynamic> data) =>
      base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');
  final header = segmento({'alg': 'HS256', 'typ': 'JWT'});
  final body = segmento(payload);
  return '$header.$body.firma-falsa';
}

int _expEnHoras(int horas) =>
    DateTime.now().toUtc().add(Duration(hours: horas)).millisecondsSinceEpoch ~/ 1000;

/// Registra los nombres de ruta usados en pushReplacementNamed — más
/// preciso que buscar texto en pantalla, ya que confirma exactamente qué
/// invocó SplashView sobre el Navigator.
class _ObservadorDeRutas extends NavigatorObserver {
  final List<String> reemplazos = [];

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute?.settings.name != null) {
      reemplazos.add(newRoute!.settings.name!);
    }
  }
}

void main() {
  late FakeSecureStorage storage;
  late MockAuthService authService;
  late _ObservadorDeRutas observador;

  setUp(() {
    storage = FakeSecureStorage();
    authService = MockAuthService();
    observador = _ObservadorDeRutas();
  });

  /// Pantallas de destino simplificadas — evita necesitar el árbol de
  /// providers completo (IIncidenteService, IStompService, etc.) que las
  /// Home views reales requieren; lo que este test verifica es que
  /// SplashView invoque pushReplacementNamed con el path correcto, no el
  /// contenido de la pantalla destino (eso lo cubren los widget tests de
  /// cada Home view individualmente).
  Widget appDePrueba(SesionViewModel sesion) {
    return ChangeNotifierProvider<SesionViewModel>.value(
      value: sesion,
      child: MaterialApp(
        navigatorObservers: [observador],
        initialRoute: AppRoutes.splash,
        routes: {
          AppRoutes.splash: (_) => const SplashView(),
          AppRoutes.roleSelection: (_) => const Scaffold(body: Text('role_selection')),
          AppRoutes.homeDenunciante: (_) => const Scaffold(body: Text('home_denunciante')),
          AppRoutes.homeAgente: (_) => const Scaffold(body: Text('home_agente')),
          AppRoutes.homeCai: (_) => const Scaffold(body: Text('home_cai')),
          AppRoutes.homeComando: (_) => const Scaffold(body: Text('home_comando')),
        },
      ),
    );
  }

  testWidgets('mientras isLoading es true, muestra el spinner y no navega', (tester) async {
    final sesion = SesionViewModel(authService: authService, storage: storage);
    // No se llama restaurarSesion() todavía — isLoading arranca en true
    // por el valor por defecto del campo, así se ve exactamente el primer
    // frame que el usuario percibe al abrir la app.

    await tester.pumpWidget(appDePrueba(sesion));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(observador.reemplazos, isEmpty);
  });

  testWidgets('sin sesión guardada, navega a roleSelection', (tester) async {
    final sesion = SesionViewModel(authService: authService, storage: storage)
      ..restaurarSesion();

    await tester.pumpWidget(appDePrueba(sesion));
    await tester.pumpAndSettle();

    expect(observador.reemplazos, [AppRoutes.roleSelection]);
    expect(find.text('role_selection'), findsOneWidget);
  });

  testWidgets('con sesión DENUNCIANTE válida, navega a homeDenunciante', (tester) async {
    await storage.write('callsos_jwt_token', _crearJwt({'exp': _expEnHoras(1)}));
    await storage.write('callsos_actor_id', 'den-001');
    await storage.write('callsos_rol', Rol.DENUNCIANTE.toJson());

    final sesion = SesionViewModel(authService: authService, storage: storage)
      ..restaurarSesion();

    await tester.pumpWidget(appDePrueba(sesion));
    await tester.pumpAndSettle();

    expect(observador.reemplazos, [AppRoutes.homeDenunciante]);
  });

  testWidgets('con sesión AGENTE válida, navega a homeAgente', (tester) async {
    await storage.write('callsos_jwt_token', _crearJwt({'exp': _expEnHoras(1)}));
    await storage.write('callsos_actor_id', 'ag-001');
    await storage.write('callsos_rol', Rol.AGENTE.toJson());

    final sesion = SesionViewModel(authService: authService, storage: storage)
      ..restaurarSesion();

    await tester.pumpWidget(appDePrueba(sesion));
    await tester.pumpAndSettle();

    expect(observador.reemplazos, [AppRoutes.homeAgente]);
  });

  testWidgets('con sesión OPERADOR_CAI válida, navega a homeCai', (tester) async {
    await storage.write('callsos_jwt_token', _crearJwt({'exp': _expEnHoras(1)}));
    await storage.write('callsos_actor_id', 'cai-001');
    await storage.write('callsos_rol', Rol.OPERADOR_CAI.toJson());

    final sesion = SesionViewModel(authService: authService, storage: storage)
      ..restaurarSesion();

    await tester.pumpWidget(appDePrueba(sesion));
    await tester.pumpAndSettle();

    expect(observador.reemplazos, [AppRoutes.homeCai]);
  });

  testWidgets('con sesión COMANDO válida, navega a homeComando', (tester) async {
    await storage.write('callsos_jwt_token', _crearJwt({'exp': _expEnHoras(1)}));
    await storage.write('callsos_actor_id', 'usr-comando');
    await storage.write('callsos_rol', Rol.COMANDO.toJson());

    final sesion = SesionViewModel(authService: authService, storage: storage)
      ..restaurarSesion();

    await tester.pumpWidget(appDePrueba(sesion));
    await tester.pumpAndSettle();

    expect(observador.reemplazos, [AppRoutes.homeComando]);
  });

  testWidgets('con JWT expirado, trata la sesión como no autenticada y navega a roleSelection', (tester) async {
    await storage.write('callsos_jwt_token', _crearJwt({'exp': _expEnHoras(-1)}));
    await storage.write('callsos_actor_id', 'den-001');
    await storage.write('callsos_rol', Rol.DENUNCIANTE.toJson());

    final sesion = SesionViewModel(authService: authService, storage: storage)
      ..restaurarSesion();

    await tester.pumpWidget(appDePrueba(sesion));
    await tester.pumpAndSettle();

    expect(observador.reemplazos, [AppRoutes.roleSelection]);
  });

  testWidgets('usa pushReplacementNamed (no push) — el usuario no puede volver al splash', (tester) async {
    final sesion = SesionViewModel(authService: authService, storage: storage)
      ..restaurarSesion();

    await tester.pumpWidget(appDePrueba(sesion));
    await tester.pumpAndSettle();

    // pushReplacementNamed dispara didReplace, no didPush, en el
    // NavigatorObserver — si SplashView cambiara a Navigator.pushNamed
    // por error, este test lo detectaría porque reemplazos quedaría vacío.
    expect(observador.reemplazos, isNotEmpty);
  });

  // ── EPIC-05 (auditoría UX/UI, hallazgo #7) ────────────────────────────

  testWidgets('muestra una animación de apertura (fade/scale) sobre ícono y marca',
      (tester) async {
    final sesion = SesionViewModel(authService: authService, storage: storage);

    await tester.pumpWidget(appDePrueba(sesion));

    // Estructural — protege contra volver a la versión estática si
    // alguien revierte el cambio sin darse cuenta.
    //
    // El ScaleTransition se busca como ANCESTRO puntual del ícono (no
    // con findsOneWidget a nivel de árbol completo): Flutter agrega su
    // propio ScaleTransition en la transición de entrada de ruta por
    // defecto (ZoomPageTransitionsBuilder de Material en Android), que
    // no tiene nada que ver con esta animación y haría fallar un conteo
    // global.
    expect(find.byType(FadeTransition), findsWidgets);
    expect(
      find.ancestor(
        of: find.byIcon(Icons.emergency_share_rounded),
        matching: find.byType(ScaleTransition),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'la navegación no espera a que la animación de apertura termine (no bloquea)',
      (tester) async {
    final sesion = SesionViewModel(authService: authService, storage: storage)
      ..restaurarSesion();

    await tester.pumpWidget(appDePrueba(sesion));
    // Deja resolver el Future de restaurarSesion() y correr el
    // addPostFrameCallback, SIN avanzar el reloj de animación lo
    // suficiente como para que el fade/scale de apertura (~900ms)
    // llegue a completarse — si la navegación estuviera erróneamente
    // encadenada a que el AnimationController termine, estos dos
    // pump() sin duración no alcanzarían para disparar `reemplazos`.
    await tester.pump();
    await tester.pump();

    expect(observador.reemplazos, isNotEmpty);
  });

  testWidgets('la animación de apertura termina en menos de 1.5s (criterio de terminado)',
      (tester) async {
    final sesion = SesionViewModel(authService: authService, storage: storage);

    await tester.pumpWidget(appDePrueba(sesion));
    // Avanza el reloj exactamente 1499ms (justo por debajo del límite
    // pedido) y verifica que, para ese entonces, la animación de
    // apertura ya llegó a su valor final (opacidad 1.0) — no solo que
    // "algo" se haya renderizado.
    await tester.pump(const Duration(milliseconds: 1499));

    final fades = tester.widgetList<FadeTransition>(find.byType(FadeTransition));
    for (final fade in fades) {
      expect(fade.opacity.value, 1.0);
    }
  });
}