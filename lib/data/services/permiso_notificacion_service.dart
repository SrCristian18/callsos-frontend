import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';

/// Resultado de la solicitud de permiso de notificaciones.
enum PermisoNotificacionResultado {
  /// El usuario concedió el permiso (o el sistema lo concede automáticamente
  /// en Android < 13).
  concedido,

  /// El usuario denegó el permiso. Se puede volver a solicitar.
  denegado,

  /// El usuario denegó permanentemente (Android: "No preguntar de nuevo").
  /// Solo resoluble llevando al usuario a ajustes del sistema.
  denegadoPermanentemente,

  /// El estado del permiso no se pudo determinar (error inesperado).
  indeterminado,
}

/// Gestiona el permiso de notificaciones push.
///
/// F.6 — Permisos de notificación (Android 13+ / iOS).
///
/// ## Android
/// - Android < 13 (API < 33): las notificaciones no requieren permiso
///   explícito del usuario — este servicio devuelve [concedido] directamente.
/// - Android 13+ (API 33+): `POST_NOTIFICATIONS` es un permiso en tiempo
///   de ejecución. Se usa [FirebaseMessaging.requestPermission] que en
///   Android 13+ delega al sistema operativo el diálogo nativo.
///
/// ## iOS
/// - Siempre requiere permiso explícito. [FirebaseMessaging.requestPermission]
///   muestra el diálogo nativo de iOS.
///
/// ## Uso recomendado
/// Llamar [solicitarPermiso] UNA VEZ, preferiblemente:
/// - Después del login del denunciante (primera sesión), antes de registrar
///   el token FCM en el backend ([NotificacionService.registrarTokenEnBackend]).
/// - O desde [NotificacionService.inicializar] (ya lo hace internamente vía
///   [FirebaseMessaging.requestPermission]).
///
/// Esta clase existe como punto de extensión explícito para cuando se
/// requiera integrar `permission_handler` (para mostrar diálogos
/// educativos previos al permiso del sistema, patrón recomendado por
/// Google Play). Por ahora delega directamente a FCM.
class PermisoNotificacionService {
  final FirebaseMessaging _fcm;

  PermisoNotificacionService({FirebaseMessaging? fcm})
      : _fcm = fcm ?? FirebaseMessaging.instance;

  /// Verifica el estado actual del permiso de notificaciones.
  ///
  /// No muestra ningún diálogo — solo consulta el estado actual.
  Future<PermisoNotificacionResultado> verificarEstado() async {
    try {
      final settings = await _fcm.getNotificationSettings();
      return _mapearEstado(settings.authorizationStatus);
    } catch (_) {
      return PermisoNotificacionResultado.indeterminado;
    }
  }

  /// Solicita el permiso de notificaciones al usuario.
  ///
  /// - En Android < 13: devuelve [concedido] sin mostrar diálogo.
  /// - En Android 13+: muestra el diálogo nativo del sistema.
  /// - En iOS: muestra el diálogo nativo de iOS.
  ///
  /// Si el usuario ya concedió o denegó permanentemente, no muestra
  /// diálogo y devuelve el estado actual.
  Future<PermisoNotificacionResultado> solicitarPermiso() async {
    try {
      // En Android < 13, requestPermission() devuelve 'authorized'
      // directamente sin mostrar diálogo (retrocompatibilidad garantizada).
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        // provisional: true en iOS permite notificaciones "silenciosas"
        // que aparecen en el centro de notificaciones sin interrupción.
        // Se usa false para pedir el permiso completo.
      );

      return _mapearEstado(settings.authorizationStatus);
    } catch (_) {
      return PermisoNotificacionResultado.indeterminado;
    }
  }

  /// Abre los ajustes de notificaciones de la app en el sistema operativo.
  ///
  /// Útil cuando el permiso fue denegado permanentemente: el usuario
  /// debe habilitarlo manualmente desde los ajustes.
  Future<void> abrirAjustesDelSistema() async {
    // FirebaseMessaging no expone este método directamente.
    // Se puede usar `app_settings` package en el futuro.
    // Por ahora se documenta como TODO.
    //
    // TODO(futuro): integrar `package:app_settings/app_settings.dart`
    // y llamar `AppSettings.openAppSettings()` aquí.
    //
    // ignore: avoid_print
    print('[Permisos] Abrir ajustes — requiere package:app_settings.');
  }

  PermisoNotificacionResultado _mapearEstado(
      AuthorizationStatus status) {
    switch (status) {
      case AuthorizationStatus.authorized:
      case AuthorizationStatus.provisional:
        return PermisoNotificacionResultado.concedido;
      case AuthorizationStatus.denied:
        // Firebase no distingue entre "denegado" y "denegado permanentemente"
        // en su enum — ambos mapean a `denied`. En Android se puede
        // distinguir con `permission_handler`, pero por ahora usamos
        // `denegado` como caso general.
        return PermisoNotificacionResultado.denegado;
      case AuthorizationStatus.notDetermined:
        return PermisoNotificacionResultado.indeterminado;
    }
  }

  /// `true` si la plataforma actual requiere solicitar permiso explícito.
  ///
  /// En Android < 13 las notificaciones no requieren permiso en tiempo
  /// de ejecución — útil para decidir si mostrar una UI educativa previa.
  static bool get requierePermisoExplicito {
    if (Platform.isIOS) return true;
    if (Platform.isAndroid) {
      // Android 13+ (API 33) introdujo POST_NOTIFICATIONS.
      // Platform.version en Dart no expone el API level directamente;
      // la verificación real se hace en runtime via FCM (getNotificationSettings).
      // Para la UI educativa, asumimos que siempre puede requerirlo en Android.
      return true;
    }
    return false;
  }
}