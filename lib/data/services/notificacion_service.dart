import 'dart:convert';
import 'dart:ui' show Color;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/enums/rol.dart';
import '../services/agente_service.dart';
import '../services/cai_service.dart';
import '../services/denunciante_service.dart';
import '../services/permiso_notificacion_service.dart';

/// Payload de una notificación push recibida del backend.
///
/// El backend siempre envía:
/// - `title`: `"Callsos — Actualización"` (fijo).
/// - `body`: mensaje contextual según el evento de dominio:
///   · "Un agente de policía va en camino a tu ubicación."
///     ([AgenteEnCaminoEvent])
///   · "Tu incidente ha sido atendido exitosamente."
///     ([IncidenteFinalizadoEvent], estado FINALIZADO)
///   · "Tu incidente ha sido cancelado."
///     ([IncidenteFinalizadoEvent], estado CANCELADO)
class NotificacionPayload {
  final String titulo;
  final String cuerpo;
  final Map<String, dynamic> datos;

  const NotificacionPayload({
    required this.titulo,
    required this.cuerpo,
    required this.datos,
  });

  factory NotificacionPayload.fromRemoteMessage(RemoteMessage message) {
    return NotificacionPayload(
      titulo: message.notification?.title ?? 'CallSOS',
      cuerpo: message.notification?.body ?? '',
      datos: Map<String, dynamic>.from(message.data),
    );
  }
}

/// Identificador del canal de notificaciones de Android.
///
/// IMPORTANTE: el ID del canal no puede cambiarse una vez que la app
/// está instalada en un dispositivo — borrar la app y reinstalar es la
/// única forma de cambiar el canal en desarrollo.
const String _kCanalId = 'callsos_alertas';
const String _kCanalNombre = 'Alertas de emergencia';
const String _kCanalDesc =
    'Notificaciones de actualización de incidentes (agente en camino, '
    'incidente finalizado, etc.)';

/// Servicio central de notificaciones push (FCM) y locales.
///
/// F.5 — Firebase / FCM.
///
/// Responsabilidades:
/// 1. [inicializar]: configura `flutter_local_notifications` (canal Android),
///    solicita permisos al usuario, y registra los handlers de FCM.
/// 2. [registrarTokenEnBackend]: obtiene el token FCM del dispositivo y lo
///    envía al backend (`PATCH /{recurso}/{actorId}/token`) para que el
///    servidor pueda enviar pushes a este dispositivo — el recurso exacto
///    depende del rol del actor autenticado (ver [registrarTokenEnBackend]).
/// 3. Muestra notificaciones locales cuando la app está en **foreground**
///    (FCM no las muestra automáticamente en foreground — requiere
///    `flutter_local_notifications`).
///
/// Uso (en [SplashView] o en el listener de [SesionViewModel]):
/// ```dart
/// final notif = NotificacionService(
///   denuncianteService: context.read<IDenuncianteService>(),
///   agenteService: context.read<IAgenteService>(),
///   caiService: context.read<ICaiService>(),
/// );
/// await notif.inicializar();
/// // Después del login/registro exitoso, para cualquier rol con soporte:
/// await notif.registrarTokenEnBackend(actorId: sesion.actorId!, rol: sesion.rol!);
/// ```
///
/// Épica 8 (hallazgo #5): ANTES este método estaba hardcodeado contra
/// [IDenuncianteService] únicamente — el docstring original decía "solo
/// el rol DENUNCIANTE recibe notificaciones push en este backend", pero
/// eso quedó desactualizado desde Épica 5: el backend expone
/// `PATCH /agentes/{id}/token` y `PATCH /cais/{id}/token` desde entonces
/// (`RegistrarTokenFcmAgenteService`, `RegistrarTokenFcmUnidadService`),
/// y `NotificacionEventListener` ya intenta notificar a agente/CAI —
/// pero como el frontend nunca registraba el token, la notificación
/// nunca salía (falla silenciosa: `tieneTokenFcm()` protege de un crash
/// en el backend, no hay ningún error visible en el cliente). Ahora
/// [registrarTokenEnBackend] recibe el [Rol] del actor y despacha al
/// servicio correcto — DENUNCIANTE, AGENTE y OPERADOR_CAI reciben push;
/// COMANDO sigue sin tokenFcm en el backend (no hay
/// `RegistrarTokenFcmComandoService`), así que se ignora silenciosamente.
class NotificacionService {
  final IDenuncianteService _denuncianteService;
  final IAgenteService _agenteService;
  final ICaiService _caiService;

  final FirebaseMessaging _fcm;
  final FlutterLocalNotificationsPlugin _localNotif;

  NotificacionService({
    required IDenuncianteService denuncianteService,
    required IAgenteService agenteService,
    required ICaiService caiService,
    FirebaseMessaging? fcm,
    FlutterLocalNotificationsPlugin? localNotif,
  })  : _denuncianteService = denuncianteService,
        _agenteService = agenteService,
        _caiService = caiService,
        _fcm = fcm ?? FirebaseMessaging.instance,
        _localNotif = localNotif ?? FlutterLocalNotificationsPlugin();

  // ── Inicialización ─────────────────────────────────────────────────

  /// Inicializa el servicio completo:
  /// 1. Crea el canal de notificaciones de Android.
  /// 2. Solicita permisos al usuario (Android 13+ / iOS).
  /// 3. Registra el handler de mensajes en foreground (FCM → local notif).
  ///
  /// Debe llamarse UNA VEZ al iniciar la app, antes de cualquier operación
  /// de notificaciones, idealmente en `main()` o en `SplashView.initState`.
  Future<void> inicializar() async {
    await _inicializarNotificacionesLocales();
    await _solicitarPermisos();
    _registrarHandlerForeground();
    _registrarHandlerBackground();
  }

  Future<void> _inicializarNotificacionesLocales() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false, // se solicita explícitamente abajo
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
    );

    await _localNotif.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onTapNotificacion,
    );

    // Crear canal de alta importancia en Android (requerido para Android 8+).
    const androidChannel = AndroidNotificationChannel(
      _kCanalId,
      _kCanalNombre,
      description: _kCanalDesc,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  Future<void> _solicitarPermisos() async {
    // F.6 — Delegar al PermisoNotificacionService.
    // En Android < 13: devuelve 'concedido' sin diálogo.
    // En Android 13+: muestra el diálogo nativo POST_NOTIFICATIONS.
    // En iOS: muestra el diálogo nativo de notificaciones.
    final permisoService = PermisoNotificacionService(fcm: _fcm);
    final resultado = await permisoService.solicitarPermiso();
    // ignore: avoid_print
    print('[FCM] Permiso de notificaciones: ${resultado.name}');
  }

  void _registrarHandlerForeground() {
    // FCM en foreground: el sistema NO muestra la notificación automáticamente.
    // La mostramos nosotros con flutter_local_notifications.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final payload = NotificacionPayload.fromRemoteMessage(message);
      if (payload.cuerpo.isNotEmpty) {
        _mostrarNotificacionLocal(payload);
      }
    });
  }

  void _registrarHandlerBackground() {
    // FCM en background/terminated: el sistema muestra la notificación.
    // Se puede interceptar el tap cuando el usuario abre la app desde ella.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // TODO(futuro): navegar al incidente relevante si el payload incluye
      // `incidenteId` en `message.data`. Por ahora solo se abre la app.
      // ignore: avoid_print
      print('[FCM] Usuario abrió la app desde notificación: ${message.data}');
    });
  }

  // ── Mostrar notificación local ─────────────────────────────────────

  Future<void> _mostrarNotificacionLocal(
      NotificacionPayload payload) async {
    const androidDetails = AndroidNotificationDetails(
      _kCanalId,
      _kCanalNombre,
      channelDescription: _kCanalDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      // Color del ícono en la barra de estado (verde oscuro CallSOS).
      color: Color(0xFF1B5E20),
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _localNotif.show(
      // ID único basado en timestamp para no sobreescribir notificaciones.
      DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF,
      payload.titulo,
      payload.cuerpo,
      details,
      payload: jsonEncode(payload.datos),
    );
  }

  void _onTapNotificacion(NotificationResponse response) {
    // El usuario tapó una notificación local.
    // TODO(futuro): navegar al incidente si el payload incluye incidenteId.
    // ignore: avoid_print
    print('[Notif local] Tap: ${response.payload}');
  }

  // ── Registro del token en el backend ──────────────────────────────

  /// Obtiene el token FCM del dispositivo y lo registra en el backend,
  /// en el recurso correcto según [rol] (Épica 8, hallazgo #5):
  /// - [Rol.DENUNCIANTE] → `PATCH /denunciantes/{actorId}/token`.
  /// - [Rol.AGENTE]      → `PATCH /agentes/{actorId}/token`.
  /// - [Rol.OPERADOR_CAI] → `PATCH /cais/{actorId}/token` (por
  ///   convención, el `actorId` de un OPERADOR_CAI ES el
  ///   `unidadPolicialId` de su propio CAI — ver `ICaiService.registrarTokenFcm`).
  /// - [Rol.COMANDO] → no-op: el backend no expone `tokenFcm` para este
  ///   rol (no hay `RegistrarTokenFcmComandoService`). Se loggea y se
  ///   retorna `null` sin llamar a ningún servicio ni obtener el token
  ///   del dispositivo — no tiene sentido pedirle un token a FCM para
  ///   luego no usarlo.
  ///
  /// IMPORTANTE — ownership: el backend valida que `actorId` del JWT
  /// coincida con el `{id}` del path en los 3 casos. Siempre pasar
  /// `sesion.actorId` y `sesion.rol` del actor autenticado actual.
  ///
  /// Llama esta función:
  /// - Inmediatamente después de un login/registro exitoso.
  /// - Al recibir `FirebaseMessaging.instance.onTokenRefresh` (el token
  ///   puede cambiar si el usuario reinstala la app o borra datos).
  ///
  /// Devuelve el token registrado, o `null` si no se pudo obtener (o si
  /// [rol] es [Rol.COMANDO]). Nunca lanza — los errores se loggean pero
  /// no bloquean el flujo.
  Future<String?> registrarTokenEnBackend({
    required String actorId,
    required Rol rol,
  }) async {
    if (rol == Rol.COMANDO) {
      // ignore: avoid_print
      print('[FCM] Rol COMANDO no tiene tokenFcm en el backend — omitido.');
      return null;
    }

    try {
      final token = await _fcm.getToken();
      if (token == null || token.isEmpty) {
        // ignore: avoid_print
        print('[FCM] No se pudo obtener el token del dispositivo.');
        return null;
      }

      await _registrarSegunRol(actorId: actorId, rol: rol, tokenFcm: token);

      // ignore: avoid_print
      print('[FCM] Token registrado en backend para actorId: $actorId '
          '(rol: ${rol.name})');

      // Suscribir al refresco automático del token.
      _fcm.onTokenRefresh.listen((nuevoToken) {
        _registrarSegunRol(actorId: actorId, rol: rol, tokenFcm: nuevoToken);
      });

      return token;
    } catch (e) {
      // ignore: avoid_print
      print('[FCM] Error al registrar token: $e');
      return null;
    }
  }

  /// Despacha al servicio de red correcto según [rol] — ver
  /// [registrarTokenEnBackend] para el detalle de cada caso. Privado:
  /// asume que ya se descartó [Rol.COMANDO] y que [tokenFcm] es válido.
  Future<void> _registrarSegunRol({
    required String actorId,
    required Rol rol,
    required String tokenFcm,
  }) {
    switch (rol) {
      case Rol.DENUNCIANTE:
        return _denuncianteService.registrarTokenFcm(
          actorId: actorId,
          tokenFcm: tokenFcm,
        );
      case Rol.AGENTE:
        return _agenteService.registrarTokenFcm(
          actorId: actorId,
          tokenFcm: tokenFcm,
        );
      case Rol.OPERADOR_CAI:
        return _caiService.registrarTokenFcm(
          unidadPolicialId: actorId,
          tokenFcm: tokenFcm,
        );
      case Rol.COMANDO:
        // Inalcanzable — registrarTokenEnBackend ya retornó antes.
        return Future.value();
    }
  }
}