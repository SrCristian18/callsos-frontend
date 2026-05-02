import 'package:CallSos/presentation/viewmodels/policia_viewmodel.dart';
import 'package:CallSos/presentation/views/forgot_password_view.dart';
import 'package:CallSos/presentation/views/login_policia_view.dart';
import 'package:CallSos/presentation/views/register_denunciante_view.dart';
import 'package:CallSos/presentation/views/register_policia_view.dart';
import 'package:CallSos/presentation/views/role_selection_view.dart';
import 'package:CallSos/presentation/views/welcome_view.dart';
import 'package:CallSos/presentation/views/home_denunciante_view.dart';
import 'package:CallSos/presentation/views/home_policia_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'presentation/views/login_view.dart';
import 'presentation/viewmodels/login_viewmodel.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LoginViewModel()),
        ChangeNotifierProvider(create: (_) => PoliciaViewModel()),
        ],
    child: MaterialApp(
      title: 'CallSOS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xfff6ffe3),
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => RoleSelectionView(),
          '/welcome': (context) => WelcomeView(),
          '/login_denunciante': (context) => LoginView(),
          '/login_policia': (context) => LoginPoliciaView(),
          '/register_denunciante': (context) => RegisterDenuncianteView(),
          '/register_policia': (context) => RegisterPoliciaView(),
          '/forgot_password': (context) => ForgotPasswordView(),
          '/home_denunciante': (context) => HomeDenuncianteView(),
          '/home_policia': (context) => HomePoliciaView(),
        },
      ),
    );
  }
}