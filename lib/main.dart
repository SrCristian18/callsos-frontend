// coverage:ignore-file
// Épica 7: excluido de la medición de cobertura — es bootstrap de la app
// (Firebase.initializeApp(), runApp()), no lógica de negocio testeable
// con flutter test. Sin esto, este archivo queda siempre en 0% y castiga
// el % global de cobertura sin aportar señal real.
import 'package:CallSos/core/app_config.dart';
import 'package:CallSos/core/app_providers.dart';
import 'package:CallSos/core/app_routes.dart';
import 'package:CallSos/core/app_text_styles.dart';
import 'package:CallSos/core/colores_app.dart';
import 'package:CallSos/presentation/viewmodels/theme_viewmodel.dart';
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

  // Bloque 3 (Épica 8) — antes solo primarySwatch +
  // scaffoldBackgroundColor. Se amplía para que botones/inputs
  // NUEVOS hereden un estilo consistente en vez de redefinirlo
  // vista por vista (hoy 65 usos de fontSize repartidos a mano).
  // No migra las vistas existentes — todas definen su propio
  // `style:` explícito (ElevatedButton.styleFrom, decoración manual
  // en CustomInput), así que esto no las afecta; solo aplica como
  // default a widgets que no sobrescriban su estilo.
  //
  // EPIC-01 (Design System, auditoría UX/UI) agrega `error` al
  // colorScheme y `textTheme` — mismo criterio de "no afecta nada
  // existente": ningún widget actual lee `Theme.of(context).colorScheme.error`
  // ni `.textTheme` (verificado con grep antes de agregar esto), así
  // que son adiciones puras. `elevatedButtonTheme`/`inputDecorationTheme`
  // de abajo NO se tocan en esta épica — sus valores literales (25, 15)
  // se dejan exactamente como están para no arriesgar ni una
  // regresión latente el día que algo empiece a heredarlos.
  static final ThemeData _temaClaro = ThemeData(
    primarySwatch: Colors.green,
    scaffoldBackgroundColor: AppColors.blancoVerde,
    colorScheme: const ColorScheme.light(
      primary: AppColors.verdeOscuro,
      secondary: AppColors.verdeClaro,
      surface: AppColors.blancoVerde,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      error: AppColors.error,
    ),
    textTheme: AppTextStyles.textTheme,
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
  );

  // EPIC-02 (Design System, auditoría UX/UI) — hallazgo #4 (sin dark
  // mode). Espejo estructural EXACTO de [_temaClaro]: mismos
  // primary/secondary/error (la marca no cambia entre modos, solo las
  // superficies se invierten — ver AppColors.fondoOscuro/superficieOscura
  // y sección 4.3 de la auditoría UX/UI). `elevatedButtonTheme` se
  // mantiene igual a propósito (backgroundColor: negroTexto ya tiene
  // buen contraste sobre fondo oscuro, no necesita variante). El único
  // cambio real frente al claro es `inputDecorationTheme.fillColor`:
  // blanco puro se vería mal en modo oscuro, así que usa
  // `superficieOscura` (un tono más claro que el fondo, no el fondo
  // mismo — así los inputs siguen distinguiéndose de la superficie).
  //
  // IMPORTANTE (alcance real de esta épica, ver criterio de terminado):
  // esto define el MECANISMO — la mayoría de las vistas actuales
  // todavía usan colores hardcodeados (`AppColors.blancoVerde`,
  // `Colors.white`, etc.) en vez de leer `Theme.of(context)`, así que
  // no se ven automáticamente correctas en modo oscuro con solo este
  // cambio. Migrar cada vista a los tokens del tema es trabajo de las
  // épicas de UI posteriores (EPIC-06 en adelante) — EPIC-02 solo
  // garantiza que el tema oscuro EXISTE, es válido, y se activa
  // correctamente (incluyendo automáticamente vía ThemeMode.system).
  static final ThemeData _temaOscuro = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.fondoOscuro,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.verdeOscuro,
      secondary: AppColors.verdeClaro,
      surface: AppColors.fondoOscuro,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.white,
      error: AppColors.error,
    ),
    textTheme: AppTextStyles.textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
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
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.superficieOscura,
      contentPadding:
          const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: AppProviders.providers,
      // EPIC-02: themeMode reactivo — Consumer en vez de context.watch
      // directo en `build()` porque MyApp.build() ya construye el
      // MaterialApp completo; envolver solo esta parte evita reconstruir
      // nada por encima de MultiProvider innecesariamente si algún día
      // hay algo ahí (hoy no lo hay, pero es el patrón correcto).
      child: Consumer<ThemeViewModel>(
        builder: (context, temaVm, _) => MaterialApp(
          // Épica 8 (hallazgo #7): ver docstring de `AppRoutes.navigatorKey`
          // — permite forzar la navegación (logout automático por sesión
          // expirada) desde el interceptor de `ApiClient`, fuera del árbol
          // de widgets.
          navigatorKey: AppRoutes.navigatorKey,
          title: 'CallSOS',
          debugShowCheckedModeBanner: false,
          theme: _temaClaro,
          darkTheme: _temaOscuro,
          themeMode: temaVm.themeMode,
          initialRoute: AppRoutes.initial,
          routes: AppRoutes.routes,
        ),
      ),
    );
  }
}