import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

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
import 'package:CallSos/data/models/enums/rol.dart';
import 'route_guard.dart';

/// Mapa de navegación completo de CallSOS.
///
/// F.0.5 — Mapa de navegación y esqueletos.
///
/// RUTA INICIAL: `/` → [SplashView], que decide hacia dónde navegar según
/// [SesionViewModel.isAuthenticated] tras [SesionViewModel.restaurarSesion].
///
/// Convención de rutas:
/// - Flujo de auth: `/role_selection`, `/welcome`, `/login_*`, `/register_*`,
///   `/forgot_password`.
/// - Homes por rol: `/home_denunciante`, `/home_agente`, `/home_cai`,
///   `/home_comando`.
/// - Flujo de incidente: `/detalle_incidente`, `/tracking`,
///   `/reporte_hallazgos`.
/// - Ajustes: `/ajustes` (EPIC-08).
///
/// Épica 3 (integración funcional completa): se retiraron las rutas legacy
/// `/incident_view` y `/report_view` — llevaban a pantallas con datos mock
/// en memoria (IncidenteView/ReporteView + IncidenteViewModel/
/// ReporteViewModel legacy), inalcanzables desde ningún flujo real de
/// navegación (confirmado: ningún Navigator.pushNamed las referenciaba).
/// Las Home views reales por rol (F.2) ya cubren esa funcionalidad.
class AppRoutes {
  AppRoutes._();

  /// Épica 8 (hallazgo #7): permite navegar desde FUERA del árbol de
  /// widgets — específicamente, desde el interceptor `onError` de
  /// [ApiClient] cuando detecta un JWT expirado/inválido en medio de una
  /// sesión activa (401 en cualquier request autenticado que no sea el
  /// login) y necesita forzar la redirección a [roleSelection].
  ///
  /// Se declara ACÁ (no directamente en `main.dart`, aunque es donde
  /// terminó pidiéndolo el hallazgo) porque tanto `main.dart`
  /// (`MaterialApp(navigatorKey: ...)`) como `app_providers.dart`
  /// (wiring de `ApiClient.onSesionInvalida`) ya importan este archivo
  /// — declararla en `main.dart` habría forzado a `app_providers.dart` a
  /// importarlo de vuelta, un ciclo (`main.dart` ya importa
  /// `app_providers.dart`). `AppRoutes` es el punto de encuentro natural
  /// entre ambos sin crear esa dependencia circular.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const String initial = '/';

  // ── Auth ────────────────────────────────────────────────────────────────
  static const String splash         = '/';
  static const String roleSelection  = '/role_selection';
  static const String welcome        = '/welcome';
  static const String loginDenunciante = '/login_denunciante';
  static const String loginPolicia   = '/login_policia';
  static const String registerDenunciante = '/register_denunciante';
  static const String registerPolicia     = '/register_policia';
  static const String forgotPassword = '/forgot_password';

  // ── Homes por rol ───────────────────────────────────────────────────────
  static const String homeDenunciante = '/home_denunciante';
  static const String homeAgente      = '/home_agente';
  static const String homeCai         = '/home_cai';
  static const String homeComando     = '/home_comando';

  // ── Flujo de incidente ──────────────────────────────────────────────────
  static const String detalleIncidente  = '/detalle_incidente';
  static const String tracking          = '/tracking';
  static const String reporteHallazgos  = '/reporte_hallazgos';

  /// EPIC-08 (Design System, auditoría UX/UI) — pantalla de Ajustes,
  /// alcanzable desde el ícono nuevo en [RoleHeader] de los 4 roles
  /// (ver criterio de terminado de la épica). Protegida con el mismo
  /// set de roles que el flujo de incidente (`_cualquierRolAutenticado`):
  /// cualquier rol autenticado puede ver/cambiar SU tema y cerrar SU
  /// sesión, no hay nada específico de un rol en particular.
  static const String ajustes = '/ajustes';

  /// EPIC-03 (Design System, auditoría UX/UI) — solo alcanzable en
  /// builds de debug (ver el `if (kDebugMode)` en [routes] más abajo).
  /// Nunca aparece en un build de release, y no requiere [RouteGuard]:
  /// es una pantalla de validación visual para desarrolladores, no
  /// parte del flujo de la app.
  static const String devComponentCatalog = '/dev/component_catalog';

  /// Home correspondiente a cada rol autenticado — usada por [SplashView]
  /// (destino tras restaurar sesión) y por [RouteGuard] (destino de
  /// redirección cuando el rol de la sesión no tiene acceso a la ruta
  /// pedida).
  static String rutaHomeDeRol(Rol rol) {
    switch (rol) {
      case Rol.DENUNCIANTE:
        return homeDenunciante;
      case Rol.AGENTE:
        return homeAgente;
      case Rol.OPERADOR_CAI:
        return homeCai;
      case Rol.COMANDO:
        return homeComando;
    }
  }

  /// Épica 5 — Testing frontend / Navegación: cualquier rol autenticado
  /// puede ver detalle/tracking/reporte de un incidente (denunciante,
  /// agente, CAI o comando) — lo que [RouteGuard] exige ahí es solo que
  /// HAYA sesión, no un rol específico.
  static const Set<Rol> _cualquierRolAutenticado = {
    Rol.DENUNCIANTE,
    Rol.AGENTE,
    Rol.OPERADOR_CAI,
    Rol.COMANDO,
  };

  /// Épica 7 (fix P6, defensa en profundidad): el DENUNCIANTE ya no
  /// tiene acceso a `/tracking` — el mapa de tracking en vivo fue
  /// retirado para ese rol (Épica 3, backend) y reemplazado por el
  /// widget de ETA en `DetalleIncidenteView`. El backend YA rechaza el
  /// SUBSCRIBE STOMP del denunciante (`StompAuthChannelInterceptor`),
  /// así que esto no es la protección real — es la segunda capa: ni
  /// siquiera debería poder LLEGAR a la pantalla, para no mostrar una
  /// vista rota (conectada pero sin datos) si de algún modo se
  /// intentara navegar ahí (ej. deep link viejo).
  static const Set<Rol> _rolesTracking = {
    Rol.AGENTE,
    Rol.OPERADOR_CAI,
    Rol.COMANDO,
  };

  static Map<String, WidgetBuilder> get routes => {
    // Splash
    splash:               (_) => const SplashView(),

    // Auth
    roleSelection:        (_) => const RoleSelectionView(),
    welcome:              (_) => const WelcomeView(),
    loginDenunciante:     (_) => const LoginView(),
    loginPolicia:         (_) => const LoginPoliciaView(),
    registerDenunciante:  (_) => const RegisterDenuncianteView(),
    registerPolicia:      (_) => const RegisterPoliciaView(),
    forgotPassword:       (_) => const ForgotPasswordView(),

    // Homes — cada una exige el rol correspondiente (F.5, guards de rol).
    homeDenunciante:      (_) => const RouteGuard(
                                    rolesPermitidos: {Rol.DENUNCIANTE},
                                    child: HomeDenuncianteView(),
                                  ),
    homeAgente:           (_) => const RouteGuard(
                                    rolesPermitidos: {Rol.AGENTE},
                                    child: HomeAgenteView(),
                                  ),
    homeCai:              (_) => const RouteGuard(
                                    rolesPermitidos: {Rol.OPERADOR_CAI},
                                    child: HomeCAIView(),
                                  ),
    homeComando:          (_) => const RouteGuard(
                                    rolesPermitidos: {Rol.COMANDO},
                                    child: HomeComandoView(),
                                  ),

    // Flujo incidente — cualquier rol autenticado.
    detalleIncidente:     (_) => const RouteGuard(
                                    rolesPermitidos: _cualquierRolAutenticado,
                                    child: DetalleIncidenteView(),
                                  ),
    tracking:             (_) => const RouteGuard(
                                    rolesPermitidos: _rolesTracking,
                                    child: TrackingView(),
                                  ),
    reporteHallazgos:     (_) => const RouteGuard(
                                    rolesPermitidos: _cualquierRolAutenticado,
                                    child: ReporteHallazgosView(),
                                  ),

    // EPIC-08 — Ajustes, cualquier rol autenticado.
    ajustes:              (_) => const RouteGuard(
                                    rolesPermitidos: _cualquierRolAutenticado,
                                    child: AjustesView(),
                                  ),

    // EPIC-03 — catálogo visual de componentes, solo en debug. Spread
    // condicional: en un build de release, esta entrada directamente
    // no existe en el mapa (no es que la ruta esté "bloqueada" — no
    // está, ni ocupa espacio en el árbol de rutas compilado).
    if (kDebugMode)
      devComponentCatalog: (_) => const ComponentCatalogView(),
  };
}