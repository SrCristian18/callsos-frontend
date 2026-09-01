/// Configuración central de la aplicación CallSOS.
///
/// F.0.1 — Fundamentos de integración.
///
/// Todos los valores se inyectan en tiempo de compilación mediante
/// `--dart-define`, evitando URLs hardcodeadas dispersas por el código
/// (capa de red F.0.3, sesión F.0.4, tracking F.3, etc.) y permitiendo
/// diferenciar entornos sin recompilar la lógica de la app.
///
/// Ejemplos de uso:
///
/// Desarrollo en emulador Android (localhost del host = 10.0.2.2):
/// ```
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
/// ```
///
/// Desarrollo en dispositivo físico (IP de la máquina en la red local):
/// ```
/// flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8080
/// ```
///
/// Producción:
/// ```
/// flutter build apk --dart-define=API_BASE_URL=https://api.callsos.com
/// ```
class AppConfig {
  AppConfig._();

  // ───────────────────────────────────────────────────────────────────────
  // API REST
  // ───────────────────────────────────────────────────────────────────────

  /// URL base del backend (sin slash final, sin sufijo /api/v1).
  ///
  /// Default: `http://localhost:8080`, válido para Flutter Web/desktop
  /// apuntando a un backend corriendo en la misma máquina.
  ///
  /// IMPORTANTE — emulador Android: `localhost` dentro del emulador apunta
  /// al propio emulador, no al host. Usar `10.0.2.2` en su lugar.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  /// Prefijo común de la API REST, espejo de los `@RequestMapping` del
  /// backend (`AuthController`, `IncidenteController`, etc., todos bajo
  /// `/api/v1`).
  static const String apiV1 = '$apiBaseUrl/api/v1';

  /// Timeout por defecto para llamadas HTTP, en milisegundos.
  /// Usado por `ApiClient` (F.0.3) al configurar `Dio` (connectTimeout,
  /// receiveTimeout, sendTimeout).
  static const int httpTimeoutMs = 15000;

  // ───────────────────────────────────────────────────────────────────────
  // WebSocket / STOMP (F.3 — tracking en tiempo real)
  // ───────────────────────────────────────────────────────────────────────

  /// URL del endpoint WebSocket del backend.
  ///
  /// El backend expone STOMP sobre `/ws` con fallback SockJS
  /// (ver `WebSocketConfig.java`). `stomp_dart_client` se conecta
  /// directamente al transporte websocket "crudo" que SockJS expone bajo
  /// `/ws/websocket`.
  ///
  /// NOTA TÉCNICA (a validar en F.3): esta ruta depende del comportamiento
  /// real de Spring + SockJS en este backend; si la conexión falla con
  /// `/ws/websocket`, probar `/ws` directo sin el sufijo, o revisar si
  /// `stomp_dart_client` requiere un cliente SockJS intermedio.
  static const String wsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'ws://localhost:8080/ws/websocket',
  );

  // ───────────────────────────────────────────────────────────────────────
  // General
  // ───────────────────────────────────────────────────────────────────────

  /// Modo debug: habilita logging verboso (interceptor de Dio, etc.).
  /// Se desactiva automáticamente en builds de release vía
  /// `--dart-define=DEBUG_MODE=false`.
  static const bool isDebug = bool.fromEnvironment(
    'DEBUG_MODE',
    defaultValue: true,
  );

  // ───────────────────────────────────────────────────────────────────────
  // Simulación de recorrido (SOLO pruebas piloto)
  // ───────────────────────────────────────────────────────────────────────

  /// Espejo de `simulacion.habilitada` en el backend (`application.yml`).
  ///
  /// Controla si el switch "Modo prueba" aparece en `HomeAgenteView`. Debe
  /// quedar en `false` (default) en cualquier build que no sea para el
  /// piloto — igual que en el backend, es un doble candado: aunque este
  /// flag esté en `true` acá, si `simulacion.habilitada=false` en el
  /// backend, el parámetro `simular=true` que manda esta app se ignora.
  ///
  /// Build para el piloto (dispositivo del tester haciendo de agente):
  /// ```
  /// flutter build apk --dart-define=MODO_PRUEBA_HABILITADO=true
  /// ```
  static const bool modoPruebaHabilitado = bool.fromEnvironment(
    'MODO_PRUEBA_HABILITADO',
    defaultValue: false,
  );

  // ───────────────────────────────────────────────────────────────────────
  // Firebase (F.5 — notificaciones push)
  // ───────────────────────────────────────────────────────────────────────

  /// Controla si la app inicializa Firebase al arrancar.
  ///
  /// Default `false` — Firebase requiere `google-services.json` (Android) y
  /// `firebase_options.dart` (generado por `flutterfire configure`), que no
  /// se generan automáticamente. Sin esos archivos,
  /// `Firebase.initializeApp()` lanza una excepción y la app no abre.
  ///
  /// Para habilitar Firebase una vez configurado:
  /// ```
  /// flutter run --dart-define=FIREBASE_ENABLED=true
  /// ```
  ///
  /// Mientras sea `false`: `main.dart` omite `Firebase.initializeApp()` y
  /// `SplashView`/`LoginView` omiten el registro del token FCM — el resto
  /// de la app (auth, incidentes, tracking, reportes) funciona con
  /// normalidad, ya que F.5 fue diseñado para no bloquear el flujo
  /// principal si las notificaciones fallan.
  static const bool firebaseHabilitado = bool.fromEnvironment(
    'FIREBASE_ENABLED',
    defaultValue: false,
  );

  // ───────────────────────────────────────────────────────────────────────
  // Metadatos de la app (EPIC-08 — Ajustes / Configuración)
  // ───────────────────────────────────────────────────────────────────────

  /// Versión visible en `AjustesView` (heurística #10 — ayuda y
  /// documentación: la versión instalada debe ser fácil de encontrar,
  /// por ejemplo para reportar un bug).
  ///
  /// Espejo manual del campo `version:` de `pubspec.yaml` — se eligió
  /// una constante simple en vez de agregar `package_info_plus` (que
  /// leería el valor real del bundle nativo) para no sumar una
  /// dependencia nueva solo para mostrar un texto informativo; ver
  /// "No modificar" de EPIC-08 (nada que requiera configuración nueva
  /// de build/backend). Costo: hay que actualizar este valor a mano
  /// cada vez que cambie `pubspec.yaml` — documentado acá para que no
  /// se desincronicen en silencio.
  static const String appVersion = '1.0.0';
}