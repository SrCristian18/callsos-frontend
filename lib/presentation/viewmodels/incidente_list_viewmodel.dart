import 'package:flutter/foundation.dart';

import '../../data/models/enums/estado_incidente.dart';
import '../../data/models/incidente.dart';
import '../../data/services/api_exception.dart';
import '../../data/services/incidente_service.dart';

/// ViewModel compartido para listas de incidentes con transiciones de estado.
///
/// F.2 — Home views por rol + Detalle de Incidente.
///
/// Cada home por rol usa este ViewModel con una función `fetchFn` distinta:
/// - [HomeDenuncianteView]: `() => service.misIncidentes()`
/// - [HomeAgenteView]:      `() => service.asignados()`
/// - [HomeCAIView]:         `() => service.porCai()`
/// - [HomeComandoView]:     `() => service.misIncidentes()` filtrado por CREADO
///   (no existe endpoint dedicado para Comando — ver F.0.7 gap 2).
///
/// Expone:
/// - [cargar] / [refrescar]: carga inicial vs. pull-to-refresh.
/// - [ejecutarTransicion]: ejecuta cualquier `PATCH` de estado del backend
///   y refresca la lista automáticamente.
/// - [incidentesPorEstado]: filtra la lista por uno o varios estados.
class IncidenteListViewModel extends ChangeNotifier {
  final IIncidenteService _service;

  /// Función que determina qué endpoint llama este ViewModel.
  final Future<List<Incidente>> Function() _fetchFn;

  IncidenteListViewModel({
    required IIncidenteService service,
    required Future<List<Incidente>> Function() fetchFn,
  })  : _service = service,
        _fetchFn = fetchFn;

  // ── Estado ─────────────────────────────────────────────────────────
  List<Incidente> _incidentes = [];
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _errorMessage;

  /// En proceso del ID que está siendo modificado (transición de estado).
  String? _idEnProceso;

  List<Incidente> get incidentes => List.unmodifiable(_incidentes);
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String? get errorMessage => _errorMessage;
  String? get idEnProceso => _idEnProceso;

  bool enProceso(String id) => _idEnProceso == id;

  /// Filtra la lista por estado(s). Útil para tabs dentro de una misma home.
  List<Incidente> incidentesPorEstado(List<EstadoIncidente> estados) =>
      _incidentes.where((i) => estados.contains(i.estado)).toList();

  // ── Operaciones de carga ───────────────────────────────────────────

  /// Carga inicial (muestra skeleton/spinner de pantalla completa).
  Future<void> cargar() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    await _fetch();
    _isLoading = false;
    notifyListeners();
  }

  /// Pull-to-refresh (no muestra spinner de pantalla completa).
  Future<void> refrescar() async {
    _isRefreshing = true;
    _errorMessage = null;
    notifyListeners();
    await _fetch();
    _isRefreshing = false;
    notifyListeners();
  }

  Future<void> _fetch() async {
    try {
      _incidentes = await _fetchFn();
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (_) {
      _errorMessage = 'No se pudieron cargar los incidentes. Intenta de nuevo.';
    }
  }

  // ── Transiciones de estado ─────────────────────────────────────────

  /// Ejecuta una transición de estado sobre [incidenteId] y refresca la lista.
  ///
  /// [accion]: función que llama al endpoint correspondiente
  ///   (`service.derivar`, `service.asignar`, `service.enCamino`, etc.).
  /// Devuelve `true` si la transición se ejecutó sin errores.
  Future<bool> ejecutarTransicion({
    required String incidenteId,
    required Future<void> Function() accion,
  }) async {
    _idEnProceso = incidenteId;
    _errorMessage = null;
    notifyListeners();

    try {
      await accion();
      await _fetch();
      _idEnProceso = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _idEnProceso = null;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Ocurrió un error inesperado. Intenta de nuevo.';
      _idEnProceso = null;
      notifyListeners();
      return false;
    }
  }
}