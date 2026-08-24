import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../data/models/enums/rol.dart';
import '../../data/models/valueobject/ubicacion.dart';
import '../../data/services/geolocalizacion_service.dart';
import 'package:CallSos/data/services/stomp_service.dart';

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
/// Épica 7: se retira por completo el modo DENUNCIANTE (fix P6 —
/// Épica 3 — ya bloqueaba esto en el backend; ahora tampoco es
/// alcanzable desde el frontend, ver `AppRoutes.tracking`/`RouteGuard`
/// y el widget de ETA que lo reemplaza en `DetalleIncidenteView`).
///
/// Opera en dos modos según el rol del usuario:
///
/// **Modo AGENTE** (emisor):
/// - Conecta al broker STOMP.
/// - Inicia [IGeolocalizacionService.streamPosicion()] con filtro de 10 m.
/// - Cada nueva posición GPS se envía a `/app/ubicacion/{incidenteId}`.
/// - También se suscribe a su propio topic de ubicación (feedback local
///   del mapa) y [posicionAgente] se actualiza además de forma optimista
///   sin esperar el eco del broker.
///
/// **Modo OPERADOR_CAI / COMANDO** (receptor):
/// - Conecta al broker STOMP.
/// - Suscribe a `/topic/agente/{agenteId}/ubicacion` — [agenteId] es el
///   del agente ASIGNADO al incidente (no el actorId de la sesión), lo
///   provee el caller (ver `DetalleIncidenteView`/`IncidenteResponse.agenteId`).
/// - Cada mensaje recibido actualiza [posicionAgente].
/// - Solicita la última posición conocida al conectarse (reconexión).
///
/// Uso en [TrackingView]:
/// ```dart
/// // initState:
/// vm.iniciar(incidenteId: id, agenteId: agenteId, rol: sesion.rol!,
///            actorId: sesion.actorId!, posicionInicial: Ubicacion(lat, lon));
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
  String? _agenteId;
  String? _actorId;
  Rol? _rol;

  // ── API pública ─────────────────────────────────────────────────────

  /// Inicia el tracking para el incidente dado.
  ///
  /// [agenteId]: id del agente cuyo topic de ubicación se sigue. En modo
  /// AGENTE (emisor) suele coincidir con [actorId] (el agente sigue su
  /// propia posición); en modo CAI/Comando (receptor) es el agente
  /// asignado al incidente, provisto por el caller.
  /// [posicionInicial]: coordenadas del incidente (para centrar el mapa
  /// y mostrar el marcador del punto de emergencia).
  Future<void> iniciar({
    required String incidenteId,
    required String agenteId,
    required Rol rol,
    required String actorId,
    Ubicacion? posicionInicial,
  }) async {
    _incidenteId = incidenteId;
    _agenteId = agenteId;
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
        // `e` ya es un mensaje armado por StompService (no una excepción
        // cruda), pero concatenarlo tal cual duplicaba el "no se pudo
        // conectar" y sonaba técnico para el usuario final (ej. "No se
        // pudo conectar al servidor de tracking: Error WebSocket:
        // Connection refused"). Mensaje único, pensado para el usuario.
        _errorMessage =
            'No se pudo conectar al servidor de tracking. Verifica tu '
            'conexión e inténtalo de nuevo.';
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
      case Rol.AGENTE:
        _iniciarModoEmisor();
      case Rol.OPERADOR_CAI:
      case Rol.COMANDO:
        _iniciarModoReceptor();
      case Rol.DENUNCIANTE:
      case null:
        // Defensa en profundidad (fix P6): esta vista ya no es
        // alcanzable por DENUNCIANTE — bloqueada en AppRoutes.tracking
        // vía RouteGuard, y reemplazada por el widget de ETA en
        // DetalleIncidenteView. Si por algún motivo se llegara hasta
        // acá igual, no se abre ningún modo de tracking: el denunciante
        // nunca debe recibir la posición GPS cruda del agente.
        _errorMessage = 'No tiene acceso al seguimiento en tiempo real.';
        _setConexion(TrackingConexionEstado.error);
    }
  }

  // ── Modo receptor (CAI / Comando) ────────────────────────────────────

  void _iniciarModoReceptor() {
    _stomp.suscribirUbicacionAgente(
      agenteId: _agenteId!,
      onMensaje: (msg) {
        _posicionAgente = LatLng(msg.latitud, msg.longitud);
        notifyListeners();
      },
    );

    // Solicitar la última posición conocida para no esperar el siguiente
    // envío del agente (útil al abrir la vista o reconectar).
    _stomp.solicitarUltimaPosicion(
      incidenteId: _incidenteId!,
      agenteId: _agenteId!,
    );
  }

  // ── Modo emisor (agente) ─────────────────────────────────────────────

  void _iniciarModoEmisor() {
    // También suscribir para ver la propia posición en el mapa (feedback).
    _stomp.suscribirUbicacionAgente(
      agenteId: _agenteId!,
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