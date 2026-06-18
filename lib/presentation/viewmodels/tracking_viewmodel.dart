import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../data/models/enums/rol.dart';
import '../../data/models/valueobject/ubicacion.dart';
import '../../data/services/geolocalizacion_service.dart';
import 'package:CallSos/data/services/stomp_sevice.dart';

/// Estados de la conexión STOMP.
enum TrackingConexionEstado {
  desconectado,
  conectando,
  conectado,
  error,
}

/// ViewModel del tracking en tiempo real.
///
/// F.3 — TrackingView + TrackingViewModel + WebSocket STOMP.
///
/// Opera en dos modos según el rol del usuario:
///
/// **Modo DENUNCIANTE** (receptor):
/// - Conecta al broker STOMP.
/// - Suscribe a `/topic/incidente/{id}/ubicacion`.
/// - Cada mensaje recibido actualiza [posicionAgente].
/// - Solicita la última posición conocida al conectarse (reconexión).
///
/// **Modo AGENTE** (emisor):
/// - Conecta al broker STOMP.
/// - Inicia [IGeolocalizacionService.streamPosicion()] con filtro de 10 m.
/// - Cada nueva posición GPS se envía a `/app/ubicacion/{id}`.
/// - [posicionAgente] también se actualiza localmente para el mapa.
///
/// Uso en [TrackingView]:
/// ```dart
/// // initState:
/// vm.iniciar(incidenteId: id, rol: sesion.rol!, actorId: sesion.actorId!,
///            posicionInicial: Ubicacion(lat, lon));
/// // dispose:
/// vm.detener();
/// ```
class TrackingViewModel extends ChangeNotifier {
  final IStompService _stomp;
  final IGeolocalizacionService _geo;

  TrackingViewModel({
    required IStompService stomp,
    required IGeolocalizacionService geo,
  })  : _stomp = stomp,
        _geo = geo;

  // ── Estado ─────────────────────────────────────────────────────────
  TrackingConexionEstado _conexion = TrackingConexionEstado.desconectado;
  LatLng? _posicionAgente;
  LatLng? _posicionDenunciante;
  String? _errorMessage;

  TrackingConexionEstado get conexion => _conexion;
  LatLng? get posicionAgente => _posicionAgente;
  LatLng? get posicionDenunciante => _posicionDenunciante;
  String? get errorMessage => _errorMessage;
  bool get estaConectado => _conexion == TrackingConexionEstado.conectado;

  // ── Internos ────────────────────────────────────────────────────────
  StreamSubscription<Ubicacion>? _gpsSubscription;
  String? _incidenteId;
  String? _actorId;
  Rol? _rol;

  // ── API pública ─────────────────────────────────────────────────────

  /// Inicia el tracking para el incidente dado.
  ///
  /// [posicionInicial]: posición del denunciante (para centrar el mapa).
  Future<void> iniciar({
    required String incidenteId,
    required Rol rol,
    required String actorId,
    Ubicacion? posicionInicial,
  }) async {
    _incidenteId = incidenteId;
    _actorId = actorId;
    _rol = rol;

    if (posicionInicial != null) {
      _posicionDenunciante =
          LatLng(posicionInicial.latitud, posicionInicial.longitud);
    }

    _setConexion(TrackingConexionEstado.conectando);

    await _stomp.conectar(
      onConnected: _onConectado,
      onError: (e) {
        _errorMessage = 'No se pudo conectar al servidor de tracking: $e';
        _setConexion(TrackingConexionEstado.error);
      },
    );
  }

  /// Detiene el tracking y libera todos los recursos.
  Future<void> detener() async {
    _gpsSubscription?.cancel();
    _gpsSubscription = null;
    await _stomp.desconectar();
    _setConexion(TrackingConexionEstado.desconectado);
  }

  // ── Handlers internos ────────────────────────────────────────────────

  void _onConectado() {
    _setConexion(TrackingConexionEstado.conectado);
    _errorMessage = null;

    switch (_rol) {
      case Rol.DENUNCIANTE:
        _iniciarModoReceptor();
      case Rol.AGENTE:
        _iniciarModoEmisor();
      default:
        // OPERADOR_CAI / COMANDO: solo reciben (misma lógica que denunciante)
        _iniciarModoReceptor();
    }
  }

  // ── Modo receptor (denunciante / CAI / Comando) ─────────────────────

  void _iniciarModoReceptor() {
    _stomp.suscribirUbicacion(
      incidenteId: _incidenteId!,
      onMensaje: (msg) {
        _posicionAgente = LatLng(msg.latitud, msg.longitud);
        notifyListeners();
      },
    );

    // Solicitar la última posición conocida para no esperar el siguiente
    // envío del agente (útil al abrir la vista o reconectar).
    _stomp.solicitarUltimaPosicion(
      incidenteId: _incidenteId!,
      agenteId: _actorId!, // en modo receptor, actorId es del denunciante —
      // el backend lo usa solo para loggear, no afecta funcionalidad.
    );
  }

  // ── Modo emisor (agente) ─────────────────────────────────────────────

  void _iniciarModoEmisor() {
    // También suscribir para ver la propia posición en el mapa (feedback).
    _stomp.suscribirUbicacion(
      incidenteId: _incidenteId!,
      onMensaje: (msg) {
        _posicionAgente = LatLng(msg.latitud, msg.longitud);
        notifyListeners();
      },
    );

    _gpsSubscription = _geo
        .streamPosicion(distanciaFiltroMetros: 10.0)
        .listen((ubicacion) {
      // Emitir posición al broker.
      _stomp.enviarUbicacion(
        incidenteId: _incidenteId!,
        agenteId: _actorId!,
        latitud: ubicacion.latitud,
        longitud: ubicacion.longitud,
      );

      // Actualizar marcador local sin esperar el echo del broker.
      _posicionAgente = LatLng(ubicacion.latitud, ubicacion.longitud);
      notifyListeners();
    }, onError: (_) {
      // Error de GPS en streaming — no detener el tracking completo,
      // solo dejar de emitir. El agente puede reiniciar la vista.
    });
  }

  void _setConexion(TrackingConexionEstado estado) {
    _conexion = estado;
    notifyListeners();
  }

  @override
  void dispose() {
    _gpsSubscription?.cancel();
    _stomp.desconectar();
    super.dispose();
  }
}