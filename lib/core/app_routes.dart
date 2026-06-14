import 'package:flutter/material.dart';
import 'package:CallSos/presentation/views/forgot_password_view.dart';
import 'package:CallSos/presentation/views/login_policia_view.dart';
import 'package:CallSos/presentation/views/register_denunciante_view.dart';
import 'package:CallSos/presentation/views/register_policia_view.dart';
import 'package:CallSos/presentation/views/role_selection_view.dart';
import 'package:CallSos/presentation/views/welcome_view.dart';
import 'package:CallSos/presentation/views/login_view.dart';
import 'package:CallSos/presentation/views/incidente_view.dart';
import 'package:CallSos/presentation/views/reporte_view.dart';

class AppRoutes {
  static const String initial = '/';

  static Map<String, WidgetBuilder> get routes => {
        '/': (context) => const RoleSelectionView(),
        '/welcome': (context) => const WelcomeView(),
        '/login_denunciante': (context) => const LoginView(),
        '/login_policia': (context) => const LoginPoliciaView(),
        '/register_denunciante': (context) => const RegisterDenuncianteView(),
        '/register_policia': (context) => const RegisterPoliciaView(),
        '/forgot_password': (context) => const ForgotPasswordView(),
        '/incident_view': (context) => const IncidenteView(),
        '/report_view': (context) => const ReporteView(),
      };
}