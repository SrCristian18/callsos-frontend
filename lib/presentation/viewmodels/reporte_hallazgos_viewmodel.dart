import 'package:flutter/foundation.dart';

import '../../data/services/api_exception.dart';
import '../../data/services/reporte_service.dart';

/// Estados del flujo de reporte de hallazgos.
enum ReporteHallazgosEstado { idle, enviando, exito, error }

/// ViewModel del formulario de reporte de hallazgos (F.4).
///
/// Orquesta `POST /api/v1/reportes/hallazgos` ({incidenteId, descripcion})
/// que, según `CrearReporteHallazgosService` del backend,
/// **también finaliza el incidente** (`incidente.finalizar()` interno).
///
/// DECISIÓN DE DISEÑO (confirmada en F.4 revisando el backend):
/// No se llama `PATCH /{id}/evaluar` por separado — hacerlo causaría un
/// error 422 (`IllegalStateException`: "Solo se puede evaluar un incidente
/// EN_ATENCION. Estado actual: FINALIZADO") porque el reporte ya lo
/// finalizó. El único endpoint necesario para cerrar el ciclo es
/// `POST /reportes/hallazgos`.
///
/// Flujo desde [HomeAgenteView] / [DetalleIncidenteView]:
/// 1. El agente pulsa "Finalizar y reportar hallazgos" → `evaluar()` en
///    el backend (EN_ATENCION → FINALIZADO) y navega a esta vista.
///    — CORRECCIÓN F.4: se elimina el paso `evaluar()` previo; directamente
///    se navega aquí y este ViewModel hace todo en un solo POST.
/// 2. El agente escribe la descripción y envía.
/// 3. En éxito: [estado] = [ReporteHallazgosEstado.exito].
///    La UI navega a [HomeAgenteView] con un snackbar de confirmación.
class ReporteHallazgosViewModel extends ChangeNotifier {
  final IReporteService _reporteService;

  ReporteHallazgosViewModel({required IReporteService reporteService})
      : _reporteService = reporteService;

  // ── Formulario ──────────────────────────────────────────────────────
  String _descripcion = '';
  String get descripcion => _descripcion;

  /// La descripción es obligatoria (no se puede enviar un reporte vacío).
  bool get formularioValido => _descripcion.trim().isNotEmpty;

  set descripcion(String value) {
    _descripcion = value;
    notifyListeners();
  }

  // ── Estado del proceso ──────────────────────────────────────────────
  ReporteHallazgosEstado _estado = ReporteHallazgosEstado.idle;
  String? _errorMessage;

  ReporteHallazgosEstado get estado => _estado;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _estado == ReporteHallazgosEstado.enviando;

  // ── Operación principal ─────────────────────────────────────────────

  /// Envía el reporte al backend.
  ///
  /// `POST /api/v1/reportes/hallazgos` — finaliza el incidente
  /// internamente (no requiere llamar `PATCH /evaluar` por separado).
  ///
  /// FIX (Épica 8, hallazgo de seguridad #1): ya no recibe `agenteId` —
  /// el backend determina quién firma el reporte a partir del JWT, no
  /// de un valor que este ViewModel le declarara. Ver el docstring de
  /// `IReporteService.crearHallazgos`.
  ///
  /// Devuelve `true` si el reporte se creó con éxito.
  /// Nunca lanza — todos los errores se exponen vía [errorMessage].
  Future<bool> enviar({
    required String incidenteId,
  }) async {
    if (!formularioValido) return false;

    _estado = ReporteHallazgosEstado.enviando;
    _errorMessage = null;
    notifyListeners();

    try {
      await _reporteService.crearHallazgos(
        incidenteId: incidenteId,
        descripcion: _descripcion.trim(),
      );

      _estado = ReporteHallazgosEstado.exito;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _estado = ReporteHallazgosEstado.error;
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (_) {
      _estado = ReporteHallazgosEstado.error;
      _errorMessage = 'Ocurrió un error inesperado al enviar el reporte.';
      notifyListeners();
      return false;
    }
  }

  /// Reinicia el ViewModel (por si el agente necesita reintentar).
  void resetear() {
    _descripcion = '';
    _estado = ReporteHallazgosEstado.idle;
    _errorMessage = null;
    notifyListeners();
  }
}