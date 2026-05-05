import 'package:CallSos/core/colores_app.dart';
import 'package:CallSos/presentation/views/report_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Modelos
import 'package:CallSos/data/models/agente_policia.dart';
import 'package:CallSos/data/models/role.dart';

// ViewModels
import 'package:CallSos/presentation/viewmodels/login_viewmodel.dart';
import 'package:CallSos/presentation/viewmodels/incident_viewmodel.dart';

// Vistas
import 'package:CallSos/presentation/views/forgot_password_view.dart';
import 'package:CallSos/presentation/views/incident_view.dart';
import 'package:CallSos/presentation/views/login_policia_view.dart';
import 'package:CallSos/presentation/views/register_denunciante_view.dart';
import 'package:CallSos/presentation/views/register_policia_view.dart';
import 'package:CallSos/presentation/views/role_selection_view.dart';
import 'package:CallSos/presentation/views/welcome_view.dart';
import 'package:CallSos/presentation/views/login_view.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Proveedor de Login
        ChangeNotifierProvider(create: (_) => LoginViewModel()),
        
        // Proveedor de Incidentes con el usuario inicial (Simulado para pruebas)
        ChangeNotifierProvider(
          create: (_) => IncidentViewModel(
/*             currentUser: AgentePolicia(
              id: '1',
              name: "Oficial Diaz",
              role: Role.COMANDO, // Aquí puedes cambiar el rol para probar las vistas
              caiId: "CAI-1",
            ),
           */),
        ),
      ],
      // El MaterialApp debe ser el child del MultiProvider para que todas las rutas tengan acceso a los datos
      child: MaterialApp(
        title: 'CallSOS',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.green,
          // Mantenemos tu color de fondo personalizado
          scaffoldBackgroundColor: AppColors.blancoVerde,
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const RoleSelectionView(),
          '/welcome': (context) => const WelcomeView(),
          '/login_denunciante': (context) => const LoginView(),
          '/login_policia': (context) => const LoginPoliciaView(),
          '/register_denunciante': (context) => const RegisterDenuncianteView(),
          '/register_policia': (context) => const RegisterPoliciaView(),
          '/forgot_password': (context) => const ForgotPasswordView(),
          '/incidentes': (context) => const IncidentView(), // Esta es la vista que alterna por rol
          '/reportes': (context) => const ReportView(),
        },
      ),
    );
  }
}