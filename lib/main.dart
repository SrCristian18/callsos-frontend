// coverage:ignore-file
// Épica 7: excluido de la medición de cobertura — es bootstrap de la app
// (Firebase.initializeApp(), runApp()), no lógica de negocio testeable
// con flutter test. Sin esto, este archivo queda siempre en 0% y castiga
// el % global de cobertura sin aportar señal real.
import 'package:CallSos/core/app_config.dart';
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

  // F.5 — Inicializar Firebase, SOLO si está habilitado explícitamente.
  //
  // AppConfig.firebaseHabilitado es `false` por defecto porque Firebase
  // requiere `google-services.json` (Android) y `firebase_options.dart`
  // (generado por `flutterfire configure`), que no se generan
  // automáticamente. Sin esos archivos, Firebase.initializeApp() lanza
  // una excepción y la app no abre.
  //
  // Para habilitar una vez configurado Firebase:
  //   flutter run --dart-define=FIREBASE_ENABLED=true
  //
  // Mientras esté deshabilitado, el resto de la app (auth, incidentes,
  // tracking, reportes) funciona con normalidad — F.5 fue diseñado para
  // no bloquear el flujo principal.
  if (AppConfig.firebaseHabilitado) {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

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
        // Bloque 3 (Épica 8) — antes solo primarySwatch +
        // scaffoldBackgroundColor. Se amplía para que botones/inputs
        // NUEVOS hereden un estilo consistente en vez de redefinirlo
        // vista por vista (hoy 65 usos de fontSize repartidos a mano).
        // No migra las vistas existentes — todas definen su propio
        // `style:` explícito (ElevatedButton.styleFrom, decoración manual
        // en CustomInput), así que esto no las afecta; solo aplica como
        // default a widgets que no sobrescriban su estilo.
        theme: ThemeData(
          primarySwatch: Colors.green,
          scaffoldBackgroundColor: AppColors.blancoVerde,
          colorScheme: const ColorScheme.light(
            primary: AppColors.verdeOscuro,
            secondary: AppColors.verdeClaro,
            surface: AppColors.blancoVerde,
            onPrimary: Colors.white,
            onSecondary: Colors.white,
          ),
          // Mismo patrón repetido en cada ElevatedButton.styleFrom de las
          // vistas actuales (login, register, home, reporte hallazgos):
          // ancho completo, esquinas redondeadas 25, fondo oscuro, texto
          // blanco. Queda como default; cada vista puede seguir
          // sobrescribiéndolo puntualmente si necesita otro color.
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.negroTexto,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
          // Mismo patrón de CustomInput (Container blanco redondeado, sin
          // borde propio) para cualquier TextField/TextFormField que se
          // use directamente sin pasar por CustomInput (ej. diálogos
          // simples como el de "Generar invitación" en HomeComandoView).
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        initialRoute: AppRoutes.initial,
        routes: AppRoutes.routes,
      ),
    );
  }
}