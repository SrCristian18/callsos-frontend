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
///
/// Épica 3 (integración funcional completa): se retiraron las rutas legacy
/// `/incident_view` y `/report_view` — llevaban a pantallas con datos mock
/// en memoria (IncidenteView/ReporteView + IncidenteViewModel/
/// ReporteViewModel legacy), inalcanzables desde ningún flujo real de
/// navegación (confirmado: ningún Navigator.pushNamed las referenciaba).
/// Las Home views reales por rol (F.2) ya cubren esa funcionalidad.
class AppRoutes {
  AppRoutes._();

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
                                    rolesPermitidos: _cualquierRolAutenticado,
                                    child: TrackingView(),
                                  ),
    reporteHallazgos:     (_) => const RouteGuard(
                                    rolesPermitidos: _cualquierRolAutenticado,
                                    child: ReporteHallazgosView(),
                                  ),
  };
}