import 'package:flutter/foundation.dart';

import '../../data/models/eta_info.dart';
import '../../data/services/incidente_service.dart';
import '../../data/services/stomp_service.dart';

/// Estado de la conexión STOMP para el widget de ETA.
enum EtaConexionEstado { desconectado, conectando, conectado, error }

/// ViewModel del widget de ETA — Épica 7.
///
/// Reemplaza el tracking en vivo para el DENUNCIANTE (retirado por fix
/// P6, Épica 3): en vez de ver la posición GPS cruda del agente en un
/// mapa, el denunciante ve minutos estimados + categoría de distancia,
/// que nunca exponen coordenadas (ver `EtaInfo`).
///
/// Combina dos fuentes de datos, igual que [TrackingViewModel] combina
/// GPS + STOMP:
/// 1. REST (`IIncidenteService.consultarEta`) — valor inicial inmediato,
///    cubre el caso de reconexión/primera carga sin esperar el primer
///    mensaje del broker.
/// 2. STOMP (`/topic/incidente/{id}/eta`) — actualizaciones en tiempo
///    real mientras el agente está en camino.
///
/// Uso (ver `EtaWidget`):
/// ```dart
/// // initState:
/// vm.iniciar(incidenteId);
/// // dispose:
/// vm.dispose();
/// ```
/// `dispose()` YA desconecta el WS por sí solo (fire-and-forget, sin
/// disparar `notifyListeners`) — no hace falta llamar a [detener] antes.
/// [detener] existe como operación explícita e independiente ("dejar de
/// escuchar ETA sin destruir el ViewModel", ej. si en el futuro se
/// quisiera pausar/reanudar), pero NUNCA debe encadenarse justo antes de
/// `dispose()`: al ser async y no poder esperarse dentro de
/// `State.dispose()` (que no es async), su `await
/// _stomp.desconectar()` puede resolver DESPUÉS de que `dispose()` ya
/// marcó el ChangeNotifier como destruido, y el `notifyListeners()` de
/// `detener()` explota con "used after being disposed" — bug real que
/// tuvo `EtaWidget` antes de este fix.
class EtaViewModel extends ChangeNotifier {
  final IStompService _stomp;
  final IIncidenteService _incidenteService;

  EtaViewModel({
    required IStompService stomp,
    required IIncidenteService incidenteService,
  })  : _stomp = stomp,
        _incidenteService = incidenteService;

  EtaInfo? _eta;
  EtaInfo? get eta => _eta;

  EtaConexionEstado _conexion = EtaConexionEstado.desconectado;
  EtaConexionEstado get conexion => _conexion;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;


  /// Inicia la carga inicial por REST y la suscripción en tiempo real.
  ///
  /// Ninguna de las dos fuentes es bloqueante para la otra: si el REST
  /// falla, igual se intenta la suscripción STOMP (y viceversa); el
  /// widget solo debe mostrar "calculando..." hasta que llegue lo
  /// primero que llegue.
  Future<void> iniciar(String incidenteId) async {

    // 1 — valor inicial por REST (no espera al primer mensaje STOMP).
    try {
      _eta = await _incidenteService.consultarEta(incidenteId);
      notifyListeners();
    } catch (_) {
      // No es fatal — seguimos con la suscripción STOMP igual. Si
      // ambas fallan, el widget mostrará el mensaje de error de la
      // conexión STOMP (más informativo que un simple "sin datos").
    }

    // 2 — suscripción en tiempo real.
    _setConexion(EtaConexionEstado.conectando);

    await _stomp.conectar(
      onConnected: () {
        _setConexion(EtaConexionEstado.conectado);
        _errorMessage = null;
        _stomp.suscribirEta(
          incidenteId: incidenteId,
          onMensaje: (info) {
            _eta = info;
            notifyListeners();
          },
        );
      },
      onError: (e) {
        _errorMessage = 'No se pudo conectar para recibir actualizaciones '
            'en tiempo real.';
        _setConexion(EtaConexionEstado.error);
      },
    );
  }

  /// Detiene la suscripción y libera la conexión STOMP.
  Future<void> detener() async {
    await _stomp.desconectar();
    _setConexion(EtaConexionEstado.desconectado);
  }

  void _setConexion(EtaConexionEstado estado) {
    _conexion = estado;
    notifyListeners();
  }

  @override
  void dispose() {
    _stomp.desconectar();
    super.dispose();
  }
}