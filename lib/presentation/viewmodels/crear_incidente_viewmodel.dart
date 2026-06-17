import 'package:flutter/foundation.dart';

import '../../data/models/enums/tipo_incidente_enum.dart';
import '../../data/models/incidente.dart';
import '../../data/services/api_exception.dart';
import '../../data/services/geolocalizacion_service.dart';
import '../../data/services/incidente_service.dart';

/// Estados del flujo de creación de incidente.
enum CrearIncidenteEstado {
  idle,
  obtenendoUbicacion,
  enviando,
  exito,
  error,
}

/// ViewModel del flujo de creación de incidente (botón de pánico).
///
/// F.1 — Flujo de creación de incidente.
///
/// Orquesta:
/// 1. Selección del [TipoIncidenteEnum].
/// 2. Descripción opcional libre.
/// 3. Permiso GPS + posición actual ([IGeolocalizacionService]).
/// 4. POST /api/v1/incidentes ([IIncidenteService.crear]).
/// 5. Resultado: [CrearIncidenteEstado.exito] con [incidenteCreado],
///    o [CrearIncidenteEstado.error] con [errorMessage].
class CrearIncidenteViewModel extends ChangeNotifier {
  final IIncidenteService _incidenteService;
  final IGeolocalizacionService _geoService;

  CrearIncidenteViewModel({
    required IIncidenteService incidenteService,
    required IGeolocalizacionService geoService,
  })  : _incidenteService = incidenteService,
        _geoService = geoService;

  // ── Formulario ──────────────────────────────────────────────────────
  TipoIncidenteEnum? _tipoSeleccionado;
  String _descripcion = '';

  TipoIncidenteEnum? get tipoSeleccionado => _tipoSeleccionado;
  String get descripcion => _descripcion;
  bool get formularioValido => _tipoSeleccionado != null;

  void seleccionarTipo(TipoIncidenteEnum tipo) {
    _tipoSeleccionado = tipo;
    notifyListeners();
  }

  set descripcion(String value) {
    _descripcion = value;
    notifyListeners();
  }

  // ── Estado del proceso ──────────────────────────────────────────────
  CrearIncidenteEstado _estado = CrearIncidenteEstado.idle;
  String? _errorMessage;
  Incidente? _incidenteCreado;

  CrearIncidenteEstado get estado => _estado;
  String? get errorMessage => _errorMessage;
  Incidente? get incidenteCreado => _incidenteCreado;

  bool get isLoading =>
      _estado == CrearIncidenteEstado.obtenendoUbicacion ||
      _estado == CrearIncidenteEstado.enviando;

  // ── Operación principal ─────────────────────────────────────────────

  /// Crea el incidente. Devuelve `true` en éxito, `false` en error.
  /// Nunca lanza — todos los errores se exponen vía [errorMessage].
  Future<bool> crearIncidente({required String denuncianteId}) async {
    if (!formularioValido) return false;

    _errorMessage = null;
    _incidenteCreado = null;
    _setEstado(CrearIncidenteEstado.obtenendoUbicacion);

    // 1 — permiso GPS
    final permiso = await _geoService.solicitarPermiso();
    if (permiso != PermisoGpsResultado.concedido) {
      _setError(_mensajePermiso(permiso));
      return false;
    }

    // 2 — posición + crear incidente
    try {
      final ubicacion = await _geoService.obtenerPosicionActual();
      _setEstado(CrearIncidenteEstado.enviando);

      final incidente = await _incidenteService.crear(
        denuncianteId: denuncianteId,
        tipo: _tipoSeleccionado!,
        descripcion: _descripcion.trim(),
        ubicacion: ubicacion,
      );

      _incidenteCreado = incidente;
      _setEstado(CrearIncidenteEstado.exito);
      return true;
    } on GeolocalizacionException catch (e) {
      _setError(e.message);
      return false;
    } on ApiException catch (e) {
      _setError(e.message);
      return false;
    } catch (_) {
      _setError('Ocurrió un error inesperado. Inténtalo de nuevo.');
      return false;
    }
  }

  /// Reinicia al estado inicial (para reusar el bottom sheet en una nueva
  /// emergencia sin recrear el ViewModel).
  void resetear() {
    _tipoSeleccionado = null;
    _descripcion = '';
    _estado = CrearIncidenteEstado.idle;
    _errorMessage = null;
    _incidenteCreado = null;
    notifyListeners();
  }

  void _setEstado(CrearIncidenteEstado e) {
    _estado = e;
    notifyListeners();
  }

  void _setError(String msg) {
    _errorMessage = msg;
    _estado = CrearIncidenteEstado.error;
    notifyListeners();
  }

  String _mensajePermiso(PermisoGpsResultado r) {
    switch (r) {
      case PermisoGpsResultado.denegado:
        return 'Se necesita acceso a la ubicación para reportar la emergencia. '
            'Por favor concede el permiso.';
      case PermisoGpsResultado.denegadoPermanentemente:
        return 'El acceso a la ubicación está bloqueado. '
            'Ve a Ajustes > Permisos de la app para habilitarlo.';
      case PermisoGpsResultado.servicioDesactivado:
        return 'El GPS está desactivado. '
            'Actívalo en los ajustes del dispositivo para continuar.';
      case PermisoGpsResultado.concedido:
        return '';
    }
  }
}