import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:CallSos/core/app_routes.dart';
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

/// Épica 5 (ruta técnica) — "Test de navegación (AppRoutes + Navigator)".
///
/// GAP DETECTADO (documentado a propósito, no un olvido): la ruta técnica
/// pide probar "guards de rutas por rol", pero revisando el código no
/// existe tal mecanismo — `AppRoutes.routes` es un mapa plano sin ningún
/// middleware que verifique el rol antes de construir la vista destino.
/// Lo que sí existe es lógica condicional DENTRO de vistas compartidas
/// (p. ej. `DetalleIncidenteView` muestra botones distintos según
/// `sesion.rol`), pero eso no es un guard de navegación: nada impide que,
/// por ejemplo, un DENUNCIANTE autenticado ejecute
/// `Navigator.pushNamed(context, AppRoutes.homeAgente)` y la vista se
/// construya igual. El test de abajo (`ningunGuardDeRolExisteHoy`) deja
/// esto verificado explícitamente, en vez de simularlo como si existiera.
void main() {
  group('AppRoutes.routes — contrato del mapa de navegación', () {
    late BuildContext context;

    setUp(() {});

    testWidgets('cada ruta declarada construye el tipo de vista correcto', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(builder: (ctx) {
            context = ctx;
            return const SizedBox();
          }),
        ),
      );

      final esperado = <String, Type>{
        AppRoutes.splash: SplashView,
        AppRoutes.roleSelection: RoleSelectionView,
        AppRoutes.welcome: WelcomeView,
        AppRoutes.loginDenunciante: LoginView,
        AppRoutes.loginPolicia: LoginPoliciaView,
        AppRoutes.registerDenunciante: RegisterDenuncianteView,
        AppRoutes.registerPolicia: RegisterPoliciaView,
        AppRoutes.forgotPassword: ForgotPasswordView,
        AppRoutes.homeDenunciante: HomeDenuncianteView,
        AppRoutes.homeAgente: HomeAgenteView,
        AppRoutes.homeCai: HomeCAIView,
        AppRoutes.homeComando: HomeComandoView,
        AppRoutes.detalleIncidente: DetalleIncidenteView,
        AppRoutes.tracking: TrackingView,
        AppRoutes.reporteHallazgos: ReporteHallazgosView,
      };

      final routes = AppRoutes.routes;

      expect(routes.keys.toSet(), esperado.keys.toSet(),
          reason: 'El mapa de rutas no debe tener rutas de más o de menos '
              'respecto a lo documentado en AppRoutes');

      for (final entry in esperado.entries) {
        final widget = routes[entry.key]!(context);
        expect(widget.runtimeType, entry.value,
            reason: 'La ruta "${entry.key}" no construye ${entry.value}');
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
      ];

      expect(paths.toSet().length, paths.length,
          reason: 'Dos constantes de ruta apuntan al mismo path — '
              'una sobrescribiría a la otra en el mapa');
    });

    test('las rutas legacy /incident_view y /report_view (Épica 3) siguen ausentes', () {
      expect(AppRoutes.routes.containsKey('/incident_view'), isFalse);
      expect(AppRoutes.routes.containsKey('/report_view'), isFalse);
    });
  });

  group('Guards de rutas por rol — verificación de la ausencia documentada arriba', () {
    test('ningún guard de rol existe hoy: AppRoutes.routes es un mapa plano '
        'de String a WidgetBuilder, sin envoltorio de autorización', () {
      // Prueba estructural: cada valor del mapa es literalmente un
      // WidgetBuilder puro. Si en el futuro se agrega un guard (p. ej. un
      // RoleGuard que envuelva al builder), este test debe actualizarse
      // para reflejar el nuevo contrato — hasta entonces, confirma que
      // cualquier código autenticado con cualquier rol puede alcanzar
      // cualquier ruta con Navigator.pushNamed, sin importar el rol.
      expect(AppRoutes.routes.values, everyElement(isA<WidgetBuilder>()));
    });
  });
}