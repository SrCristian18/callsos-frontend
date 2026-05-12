import 'package:CallSos/core/colores_app.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Modelos
import 'package:CallSos/data/models/agente_policia.dart';
import 'package:CallSos/data/models/enums/rol.dart';
import 'package:CallSos/data/models/enums/estado_agente.dart';


// ViewModels
import 'package:CallSos/presentation/viewmodels/login_viewmodel.dart';
import 'package:CallSos/presentation/viewmodels/reporte_viewmodel.dart';
import 'package:CallSos/presentation/viewmodels/incidente_viewmodel.dart';

// Vistas
import 'package:CallSos/presentation/views/forgot_password_view.dart';
import 'package:CallSos/presentation/views/login_policia_view.dart';
import 'package:CallSos/presentation/views/register_denunciante_view.dart';
import 'package:CallSos/presentation/views/register_policia_view.dart';
import 'package:CallSos/presentation/views/role_selection_view.dart';
import 'package:CallSos/presentation/views/welcome_view.dart';
import 'package:CallSos/presentation/views/login_view.dart';
import 'package:CallSos/presentation/views/incidente_view.dart';
import 'package:CallSos/presentation/views/reporte_view.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Proveedor de Login
        ChangeNotifierProvider(create: (_) => LoginViewModel()),
        ChangeNotifierProvider(create: (_) => ReporteViewModel()),
        ChangeNotifierProvider(
          create: (_) => IncidenteViewModel(
            currentUser: AgentePolicia(
              id: 'comando-1',
              nombre: 'Oficial de Prueba',
              rol: Rol.JEFE_CAI,
              cai: 'CAI San Francisco',
              estadoAgente: EstadoAgente.DISPONIBLE,
            ),
          ),
        ),
      ],
      // El MaterialApp debe ser el child del MultiProvider para que todas las rutas tengan acceso a los datos
      child: MaterialApp(
        title: 'CallSOS',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.green,
          scaffoldBackgroundColor: AppColors.blancoVerde,
        ),
        initialRoute: '/', //despues de prueba, borrar
        routes: {
          '/': (context) => const RoleSelectionView(),
          '/welcome': (context) => const WelcomeView(),
          '/login_denunciante': (context) => const LoginView(),
          '/login_policia': (context) => const LoginPoliciaView(),
          '/register_denunciante': (context) => const RegisterDenuncianteView(),
          '/register_policia': (context) => const RegisterPoliciaView(),
          '/forgot_password': (context) => const ForgotPasswordView(),
          '/incident_view': (context) => const IncidenteView(),
          '/report_view': (context) => const ReporteView(),
        },
      ),
    );
  }
}