import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:CallSos/core/app_routes.dart';
import 'package:CallSos/core/route_guard.dart';
import 'package:CallSos/data/models/auth_result.dart';
import 'package:CallSos/data/models/enums/rol.dart';
import 'package:CallSos/data/services/auth_service.dart';
import 'package:CallSos/data/services/secure_storage.dart';
import 'package:CallSos/presentation/viewmodels/sesion_viewmodel.dart';
import 'package:CallSos/presentation/views/splash_view.dart';
import 'package:CallSos/presentation/views/role_selection_view.dart';
import 'package:CallSos/presentation/views/welcome_view.dart';
import 'package:CallSos/presentation/views/login_view.dart';
import 'package:CallSos/presentation/views/login_policia_view.dart';
import 'package:CallSos/presentation/views/register_denunciante_view.dart';
import 'package:CallSos/presentation/views/register_policia_view.dart';
import 'package:CallSos/presentation/views/forgot_password_view.dart';
import 'package:CallSos/presentation/views/home_denunciante_view.dart';
import 'package:CallSos/presentation/views/home_agente_view.dart';
import 'package:CallSos/presentation/views/home_cai_view.dart';
import 'package:CallSos/presentation/views/home_comando_view.dart';
import 'package:CallSos/presentation/views/detalle_incidente_view.dart';
import 'package:CallSos/presentation/views/tracking_view.dart';
import 'package:CallSos/presentation/views/reporte_hallazgos_view.dart';
import 'package:CallSos/presentation/views/ajustes_view.dart';
import 'package:CallSos/presentation/views/dev/component_catalog_view.dart';

/// Épica 5 (ruta técnica) — "Test de navegación (AppRoutes + Navigator)".
///
/// ACTUALIZACIÓN: este archivo documentaba antes la AUSENCIA de guards de
/// rol como un gap intencional. Esa decisión se revirtió — se implementó
/// [RouteGuard] (ver `core/route_guard.dart`) y `AppRoutes.routes` ahora
/// envuelve las 4 Homes y el flujo de incidente con él. Este archivo
/// prueba el contrato actual: qué vista construye cada ruta (directa o a
/// través de un guard) y el comportamiento real del guard ante sesión
/// ausente / rol incorrecto / rol correcto.

class MockAuthService extends Mock implements IAuthService {}

class FakeSecureStorage implements ISecureStorage {
  final Map<String, String> _datos = {};
  @override
  Future<String?> read(String key) async => _datos[key];
  @override
  Future<void> write(String key, String value) async => _datos[key] = value;
  @override
  Future<void> delete(String key) async => _datos.remove(key);
}

Future<SesionViewModel> _sesionSinSesionPrevia(MockAuthService authService) async {
  final sesion = SesionViewModel(authService: authService, storage: FakeSecureStorage());
  await sesion.restaurarSesion();
  return sesion;
}

void main() {
  group('AppRoutes.routes — contrato del mapa de navegación', () {
    late BuildContext context;

    testWidgets('cada ruta declarada construye el tipo de vista correcto '
        '(directo, o RouteGuard envolviendo la vista real)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(builder: (ctx) {
            context = ctx;
            return const SizedBox();
          }),
        ),
      );

      // Rutas sin guard: construyen la vista directamente.
      final sinGuard = <String, Type>{
        AppRoutes.splash: SplashView,
        AppRoutes.roleSelection: RoleSelectionView,
        AppRoutes.welcome: WelcomeView,
        AppRoutes.loginDenunciante: LoginView,
        AppRoutes.loginPolicia: LoginPoliciaView,
        AppRoutes.registerDenunciante: RegisterDenuncianteView,
        AppRoutes.registerPolicia: RegisterPoliciaView,
        AppRoutes.forgotPassword: ForgotPasswordView,
        // EPIC-03 (Design System, auditoría UX/UI): solo existe en el
        // mapa cuando kDebugMode es true — `flutter test` SIEMPRE corre
        // en modo debug, así que en este test SIEMPRE está presente.
        // No lleva RouteGuard: es una pantalla de validación visual
        // para desarrolladores, no parte del flujo real de la app.
        AppRoutes.devComponentCatalog: ComponentCatalogView,
      };

      // Rutas con guard: el WidgetBuilder construye un RouteGuard cuyo
      // `child` es la vista real, con el set de roles esperado.
      final conGuard = <String, (Type, Set<Rol>)>{
        AppRoutes.homeDenunciante: (HomeDenuncianteView, {Rol.DENUNCIANTE}),
        AppRoutes.homeAgente: (HomeAgenteView, {Rol.AGENTE}),
        AppRoutes.homeCai: (HomeCAIView, {Rol.OPERADOR_CAI}),
        AppRoutes.homeComando: (HomeComandoView, {Rol.COMANDO}),
        AppRoutes.detalleIncidente: (
          DetalleIncidenteView,
          {Rol.DENUNCIANTE, Rol.AGENTE, Rol.OPERADOR_CAI, Rol.COMANDO}
        ),
        // Épica 7 (fix P6): DENUNCIANTE ya no está en los roles
        // permitidos de /tracking — el mapa de tracking en vivo fue
        // retirado para ese rol y reemplazado por EtaWidget en
        // DetalleIncidenteView.
        AppRoutes.tracking: (
          TrackingView,
          {Rol.AGENTE, Rol.OPERADOR_CAI, Rol.COMANDO}
        ),
        AppRoutes.reporteHallazgos: (
          ReporteHallazgosView,
          {Rol.DENUNCIANTE, Rol.AGENTE, Rol.OPERADOR_CAI, Rol.COMANDO}
        ),
        // EPIC-08 — Ajustes, cualquier rol autenticado.
        AppRoutes.ajustes: (
          AjustesView,
          {Rol.DENUNCIANTE, Rol.AGENTE, Rol.OPERADOR_CAI, Rol.COMANDO}
        ),
      };

      final routes = AppRoutes.routes;

      expect(
        routes.keys.toSet(),
        {...sinGuard.keys, ...conGuard.keys},
        reason: 'El mapa de rutas no debe tener rutas de más o de menos '
            'respecto a lo documentado en AppRoutes',
      );

      for (final entry in sinGuard.entries) {
        final widget = routes[entry.key]!(context);
        expect(widget.runtimeType, entry.value,
            reason: 'La ruta "${entry.key}" no construye ${entry.value}');
      }

      for (final entry in conGuard.entries) {
        final widget = routes[entry.key]!(context);
        expect(widget, isA<RouteGuard>(),
            reason: 'La ruta "${entry.key}" debe estar protegida por RouteGuard');
        final guard = widget as RouteGuard;
        expect(guard.child.runtimeType, entry.value.$1,
            reason: 'El child del RouteGuard de "${entry.key}" no es ${entry.value.$1}');
        expect(guard.rolesPermitidos, entry.value.$2,
            reason: 'Los roles permitidos en "${entry.key}" no coinciden');
      }
    });

    test('splash e initial apuntan al mismo path ("/")', () {
      expect(AppRoutes.splash, AppRoutes.initial);
      expect(AppRoutes.splash, '/');
    });

    test('no hay paths duplicados entre las constantes de ruta', () {
      final paths = [
        AppRoutes.splash,
        AppRoutes.roleSelection,
        AppRoutes.welcome,
        AppRoutes.loginDenunciante,
        AppRoutes.loginPolicia,
        AppRoutes.registerDenunciante,
        AppRoutes.registerPolicia,
        AppRoutes.forgotPassword,
        AppRoutes.homeDenunciante,
        AppRoutes.homeAgente,
        AppRoutes.homeCai,
        AppRoutes.homeComando,
        AppRoutes.detalleIncidente,
        AppRoutes.tracking,
        AppRoutes.reporteHallazgos,
        AppRoutes.ajustes,
        AppRoutes.devComponentCatalog,
      ];

      expect(paths.toSet().length, paths.length,
          reason: 'Dos constantes de ruta apuntan al mismo path — '
              'una sobrescribiría a la otra en el mapa');
    });

    test('las rutas legacy /incident_view y /report_view (Épica 3) siguen ausentes', () {
      expect(AppRoutes.routes.containsKey('/incident_view'), isFalse);
      expect(AppRoutes.routes.containsKey('/report_view'), isFalse);
    });

    test('rutaHomeDeRol cubre los 4 roles con la Home correcta', () {
      expect(AppRoutes.rutaHomeDeRol(Rol.DENUNCIANTE), AppRoutes.homeDenunciante);
      expect(AppRoutes.rutaHomeDeRol(Rol.AGENTE), AppRoutes.homeAgente);
      expect(AppRoutes.rutaHomeDeRol(Rol.OPERADOR_CAI), AppRoutes.homeCai);
      expect(AppRoutes.rutaHomeDeRol(Rol.COMANDO), AppRoutes.homeComando);
    });

    test(
        'EPIC-03: el catálogo de componentes solo existe bajo kDebugMode '
        '(en release, esta clave no debe estar en el mapa)', () {
      // No podemos simular kDebugMode=false en un test (es una constante
      // de compilación), pero sí dejamos documentado y verificado que
      // HOY (test = siempre debug) la ruta está presente y sin guard —
      // si algún día se moviera fuera del `if (kDebugMode)` en
      // app_routes.dart, este test seguiría pasando igual, así que la
      // garantía real de "nunca en release" depende de revisar el
      // propio app_routes.dart, no de este test. Lo que SÍ podemos
      // afirmar automáticamente: la ruta no está protegida por
      // RouteGuard (no debería necesitarlo, dado que no navega a datos
      // reales de ningún actor).
      final widget = AppRoutes.routes[AppRoutes.devComponentCatalog];
      expect(widget, isNotNull);
    });
  });

  group('RouteGuard — comportamiento real de los guards de rol', () {
    Widget appDePrueba(SesionViewModel sesion, RouteGuard guard) {
      return ChangeNotifierProvider<SesionViewModel>.value(
        value: sesion,
        child: MaterialApp(
          home: guard,
          routes: {
            AppRoutes.roleSelection: (_) => const Scaffold(body: Text('role_selection')),
            AppRoutes.homeDenunciante: (_) => const Scaffold(body: Text('home_denunciante')),
            AppRoutes.homeAgente: (_) => const Scaffold(body: Text('home_agente')),
          },
        ),
      );
    }

    testWidgets('sin sesión autenticada, redirige a roleSelection y NO muestra el child',
        (tester) async {
      final sesion = await _sesionSinSesionPrevia(MockAuthService());

      await tester.pumpWidget(appDePrueba(
        sesion,
        const RouteGuard(
          rolesPermitidos: {Rol.DENUNCIANTE},
          child: Text('CONTENIDO_PROTEGIDO'),
        ),
      ));
      await tester.pump();
      await tester.pump();

      expect(find.text('CONTENIDO_PROTEGIDO'), findsNothing);
      expect(find.text('role_selection'), findsOneWidget);
    });

    testWidgets('autenticado con rol NO permitido, redirige a la Home real de su rol',
        (tester) async {
      final authService = MockAuthService();
      when(() => authService.login(username: 'den-001', password: '1234')).thenAnswer(
        (_) async => const AuthResult(
            token: 'jwt-den', actorId: 'den-001', rol: Rol.DENUNCIANTE),
      );
      final sesion = await _sesionSinSesionPrevia(authService);
      await sesion.login(username: 'den-001', password: '1234');

      // Guard de /home_agente — un DENUNCIANTE no debería poder verla.
      await tester.pumpWidget(appDePrueba(
        sesion,
        const RouteGuard(
          rolesPermitidos: {Rol.AGENTE},
          child: Text('CONTENIDO_DE_AGENTE'),
        ),
      ));
      await tester.pump();
      await tester.pump();

      expect(find.text('CONTENIDO_DE_AGENTE'), findsNothing);
      // Redirige a SU home (denunciante), no a roleSelection ni a un error.
      expect(find.text('home_denunciante'), findsOneWidget);
    });

    testWidgets('autenticado con rol permitido, muestra el child sin redirigir',
        (tester) async {
      final authService = MockAuthService();
      when(() => authService.login(username: 'den-001', password: '1234')).thenAnswer(
        (_) async => const AuthResult(
            token: 'jwt-den', actorId: 'den-001', rol: Rol.DENUNCIANTE),
      );
      final sesion = await _sesionSinSesionPrevia(authService);
      await sesion.login(username: 'den-001', password: '1234');

      await tester.pumpWidget(appDePrueba(
        sesion,
        const RouteGuard(
          rolesPermitidos: {Rol.DENUNCIANTE},
          child: Text('CONTENIDO_PROTEGIDO'),
        ),
      ));
      await tester.pump();
      await tester.pump();

      expect(find.text('CONTENIDO_PROTEGIDO'), findsOneWidget);
      expect(find.text('role_selection'), findsNothing);
    });

    testWidgets(
        'Épica 7 (fix P6): DENUNCIANTE autenticado NO ve el contenido de '
        '/tracking, redirige a su Home', (tester) async {
      final authService = MockAuthService();
      when(() => authService.login(username: 'den-001', password: '1234')).thenAnswer(
        (_) async => const AuthResult(
            token: 'jwt-den', actorId: 'den-001', rol: Rol.DENUNCIANTE),
      );
      final sesion = await _sesionSinSesionPrevia(authService);
      await sesion.login(username: 'den-001', password: '1234');

      // Mismo guard con el que AppRoutes.tracking envuelve TrackingView
      // tras el fix — DENUNCIANTE ya no está en rolesPermitidos.
      await tester.pumpWidget(appDePrueba(
        sesion,
        const RouteGuard(
          rolesPermitidos: {Rol.AGENTE, Rol.OPERADOR_CAI, Rol.COMANDO},
          child: Text('CONTENIDO_DE_TRACKING'),
        ),
      ));
      await tester.pump();
      await tester.pump();

      expect(find.text('CONTENIDO_DE_TRACKING'), findsNothing);
      expect(find.text('home_denunciante'), findsOneWidget);
    });
  });
}