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

    // Homes
    homeDenunciante:      (_) => const HomeDenuncianteView(),
    homeAgente:           (_) => const HomeAgenteView(),
    homeCai:              (_) => const HomeCAIView(),
    homeComando:          (_) => const HomeComandoView(),

    // Flujo incidente
    detalleIncidente:     (_) => const DetalleIncidenteView(),
    tracking:             (_) => const TrackingView(),
    reporteHallazgos:     (_) => const ReporteHallazgosView(),
  };
}