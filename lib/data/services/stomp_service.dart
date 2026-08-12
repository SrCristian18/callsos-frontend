import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../../core/app_config.dart';
import '../services/token_provider.dart';

/// Mensaje de ubicación recibido del backend vía STOMP.
///
/// Espejo de `UbicacionAgenteController.UbicacionResponse` (Java):
/// ```json
/// { "latitud": 10.391, "longitud": -75.4794, "timestamp": "..." }
/// ```
class UbicacionMensaje {
  final double latitud;
  final double longitud;
  final String timestamp;

  const UbicacionMensaje({
    required this.latitud,
    required this.longitud,
    required this.timestamp,
  });

  factory UbicacionMensaje.fromJson(Map<String, dynamic> json) {
    return UbicacionMensaje(
      latitud: (json['latitud'] as num).toDouble(),
      longitud: (json['longitud'] as num).toDouble(),
      timestamp: json['timestamp'] as String? ?? '',
    );
  }
}

/// Abstracción sobre `stomp_dart_client` para el canal de tracking.
///
/// F.3 — TrackingView + TrackingViewModel + WebSocket STOMP.
///
/// Permite mockear en tests sin conexión real (ver [IStompService]).
abstract class IStompService {
  /// Conecta al endpoint STOMP del backend.
  ///
  /// [onConnected]: callback invocado cuando la conexión STOMP está activa
  /// (frame CONNECTED recibido). Seguro para empezar a suscribir/enviar.
  /// [onError]: callback invocado ante errores de conexión o frames ERROR.
  Future<void> conectar({
    required VoidCallback onConnected,
    required void Function(String error) onError,
  });

  /// Desconecta del servidor STOMP y libera recursos.
  Future<void> desconectar();

  /// Suscribe al topic de ubicación del incidente.
  ///
  /// Devuelve un [StreamSubscription]-equivalente que puede cancelarse
  /// con [cancelarSuscripcion].
  ///
  /// Destino: `/topic/incidente/{incidenteId}/ubicacion`
  void suscribirUbicacion({
    required String incidenteId,
    required void Function(UbicacionMensaje) onMensaje,
  });

  /// Cancela la suscripción al topic de ubicación.
  void cancelarSuscripcion();

  /// Envía la posición GPS del agente al backend.
  ///
  /// Destino: `/app/ubicacion/{incidenteId}`
  /// Payload: `{agenteId, latitud, longitud}`
  void enviarUbicacion({
    required String incidenteId,
    required String agenteId,
    required double latitud,
    required double longitud,
  });

  /// Solicita la última posición conocida del agente (reconexión).
  ///
  /// Destino: `/app/ubicacion/{incidenteId}/ultima`
  /// Payload: `{agenteId}`
  void solicitarUltimaPosicion({
    required String incidenteId,
    required String agenteId,
  });

  bool get estaConectado;
}

/// Implementación real de [IStompService] sobre `stomp_dart_client`.
///
/// NOTA TÉCNICA (validada contra WebSocketConfig.java):
/// El backend registra el endpoint `/ws` con `.withSockJS()`.
/// SockJS expone el transporte WebSocket raw en `{base}/ws/websocket`.
/// `stomp_dart_client` se conecta directamente a esta URL sin necesitar
/// la capa de handshake SockJS completa.
///
/// URL resultante (desarrollo): `ws://10.0.2.2:8080/ws/websocket`
/// (ver [AppConfig.wsBaseUrl]).
///
/// Autenticación: el JWT se envía en el header STOMP `Authorization`
/// (frame CONNECT). A diferencia de los endpoints REST (donde
/// JwtAuthFilter valida el JWT vía un filtro de Servlet sobre el
/// handshake HTTP), el WebSocket usa un mecanismo separado:
/// StompAuthChannelInterceptor intercepta el frame CONNECT de STOMP
/// (protocolo aparte del handshake HTTP) y valida el JWT ahí. El
/// handshake HTTP en sí (/ws/**) está en permitAll() a propósito,
/// porque no todos los clientes garantizan poder enviar headers custom
/// en esa etapa — la autenticación real ocurre en el CONNECT de STOMP.
class StompService implements IStompService {
  final ITokenProvider? tokenProvider;

  /// Fábrica del `StompClient` real — inyectable para tests.
  ///
  /// Épica 5 — Testing frontend / StompService: antes, `conectar()`
  /// instanciaba `StompClient(...)` directamente, sin ningún punto de
  /// inyección — imposible de testear sin una conexión WebSocket real.
  /// Por defecto usa el constructor real (`StompClient.new`); en tests
  /// se sustituye por una que devuelve un mock, lo que permite capturar
  /// el [StompConfig] pasado y simular manualmente los callbacks de
  /// ciclo de vida (`onConnect`, `onStompError`, `onWebSocketError`,
  /// `onDisconnect`) sin abrir un socket de verdad — eso es lo que
  /// prueba el "contrato de reconexión/errores": que StompService
  /// interprete y propague correctamente esos eventos (el reintento
  /// automático en sí, basado en Timer, vive dentro de StompClient/el
  /// paquete `stomp_dart_client`, no en este código).
  final StompClient Function({required StompConfig config}) _creadorCliente;

  StompClient? _client;
  StompUnsubscribe? _suscripcionActual;
  bool _conectado = false;

  StompService({
    this.tokenProvider,
    StompClient Function({required StompConfig config})? creadorCliente,
  }) : _creadorCliente = creadorCliente ?? StompClient.new;

  @override
  bool get estaConectado => _conectado;

  @override
  Future<void> conectar({
    required VoidCallback onConnected,
    required void Function(String error) onError,
  }) async {
    if (_conectado) return;

    final token = tokenProvider?.token;
    final stompHeaders = <String, String>{
      if (token != null) 'Authorization': 'Bearer $token',
    };

    _client = _creadorCliente(
      config: StompConfig(
        url: AppConfig.wsBaseUrl,
        stompConnectHeaders: stompHeaders,
        webSocketConnectHeaders: stompHeaders,
        onConnect: (frame) {
          print("✅ STOMP CONECTADO");
          _conectado = true;
          onConnected();
        },
        onStompError: (frame) {
          print("❌ STOMP ERROR");
          print(frame.body);

          _conectado = false;
          onError(frame.body ?? 'Error STOMP desconocido');
        },
        onWebSocketError: (error) {
          print("❌ WEBSOCKET ERROR");
          print(error);

          _conectado = false;
          onError('Error WebSocket: $error');
        },
        onDisconnect: (_) {
          _conectado = false;
        },
        reconnectDelay: const Duration(seconds: 5),
        heartbeatOutgoing: const Duration(seconds: 10),
        heartbeatIncoming: const Duration(seconds: 10),
      ),
    );

    _client!.activate();
  }

  @override
  Future<void> desconectar() async {
    cancelarSuscripcion();
    _client?.deactivate();
    _client = null;
    _conectado = false;
  }

  @override
  void suscribirUbicacion({
    required String incidenteId,
    required void Function(UbicacionMensaje) onMensaje,
  }) {
    if (_client == null || !_conectado) return;

    _suscripcionActual = _client!.subscribe(
      destination: '/topic/incidente/$incidenteId/ubicacion',
      callback: (frame) {
        if (frame.body == null || frame.body!.isEmpty) return;
        try {
          final json = jsonDecode(frame.body!) as Map<String, dynamic>;
          onMensaje(UbicacionMensaje.fromJson(json));
        } catch (_) {
          // Payload malformado — ignorar silenciosamente para no
          // tumbar el tracking por un frame corrupto.
        }
      },
    );
  }

  @override
  void cancelarSuscripcion() {
    _suscripcionActual?.call();
    _suscripcionActual = null;
  }

  @override
  void enviarUbicacion({
    required String incidenteId,
    required String agenteId,
    required double latitud,
    required double longitud,
  }) {
    if (_client == null || !_conectado) return;

    _client!.send(
      destination: '/app/ubicacion/$incidenteId',
      body: jsonEncode({
        'agenteId': agenteId,
        'latitud': latitud,
        'longitud': longitud,
      }),
    );
  }

  @override
  void solicitarUltimaPosicion({
    required String incidenteId,
    required String agenteId,
  }) {
    if (_client == null || !_conectado) return;

    _client!.send(
      destination: '/app/ubicacion/$incidenteId/ultima',
      body: jsonEncode({'agenteId': agenteId}),
    );
  }
}