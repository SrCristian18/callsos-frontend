import 'package:CallSos/presentation/views/login_policia_view.dart';
import 'package:CallSos/presentation/views/role_selection_view.dart';
import 'package:CallSos/presentation/views/welcome_view.dart';
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
        },
      ),
    );
  }
}