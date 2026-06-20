import 'package:CallSos/core/app_providers.dart';
import 'package:CallSos/core/app_routes.dart';
import 'package:CallSos/core/colores_app.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Handler de mensajes FCM en background/terminated.
///
/// F.5 — Firebase / FCM.
///
/// IMPORTANTE: debe ser una función TOP-LEVEL (fuera de cualquier clase)
/// porque Firebase la ejecuta en un isolate separado donde no existe el
/// contexto de Flutter ni el árbol de widgets.
///
/// En background/terminated, el sistema ya muestra la notificación
/// automáticamente (usando el canal Android definido en NotificacionService).
/// Este handler se usa solo para lógica adicional (ej. actualizar badges,
/// pre-cargar datos), no para mostrar la notificación en sí.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase debe inicializarse también en el isolate de background.
  await Firebase.initializeApp();
  // ignore: avoid_print
  print('[FCM Background] Mensaje recibido: ${message.messageId}');
  // No se necesita mostrar notificación local aquí — el sistema lo hace.
  // Si se requiere lógica adicional (ej. actualizar cache), va aquí.
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // F.5 — Inicializar Firebase.
  //
  // NOTA: Firebase.initializeApp() requiere que el proyecto esté conectado
  // a Firebase Console y que existan los archivos de configuración:
  // - Android: android/app/google-services.json
  // - iOS:     ios/Runner/GoogleService-Info.plist
  //
  // Estos archivos NO se generan automáticamente — deben crearse con
  // FlutterFire CLI: `flutterfire configure` (ver docs/deuda_backend.md F.5).
  //
  // Mientras no estén configurados, Firebase.initializeApp() lanzará una
  // excepción. Para continuar el desarrollo sin Firebase, comentar este
  // bloque temporalmente y las referencias a NotificacionService en
  // AppProviders.
  await Firebase.initializeApp();

  // Registrar el handler de background ANTES de runApp.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: AppProviders.providers,
      child: MaterialApp(
        title: 'CallSOS',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.green,
          scaffoldBackgroundColor: AppColors.blancoVerde,
        ),
        initialRoute: AppRoutes.initial,
        routes: AppRoutes.routes,
      ),
    );
  }
}