import 'package:CallSos/data/models/agente_policia.dart';
import 'package:CallSos/data/models/enums/estado_incidente.dart';
import 'package:CallSos/data/models/incidente_reportado.dart';
import 'package:CallSos/data/models/tipo_incidente.dart';
import 'package:flutter/material.dart';


class IncidenteViewModel extends ChangeNotifier {
  final AgentePolicia currentUser;
  bool _isLoading = false;

  bool get isLoading => _isLoading;
  set isLoading(bool val) { _isLoading = val; notifyListeners(); }

  IncidenteViewModel({required this.currentUser});

  // Catálogo de tipos de incidentes (para el denunciante)
  final List<TipoIncidente> catalogTypes = [
    TipoIncidente(id: '1',titulo: "Riña", descripcion: "Enfrentamiento entre grupos", icono: Icons.fitness_center, color: Colors.red),
  ];

  // Lista maestra de incidentes en memoria
  final List<IncidenteReportado> _allIncidents = [
    IncidenteReportado(
      id: 'inc-001',
      incidente: TipoIncidente(id: '1', titulo: "Riña", descripcion: "Pelea callejera", icono: Icons.fitness_center, color: Colors.red),
      fechaCreacion: DateTime.now(),
      ubicacion: "Parque Simón Bolívar",
      detalles: "Se reporta una riña entre dos personas en el sector norte.",
      estado: EstadoIncidente.RECIBIDO,
    ),
  ];

  // --- GETTERS FILTRADOS POR ROL ---

  // Para el Denunciante
  List<IncidenteReportado> get misReportes => _allIncidents.where((i) => i.id == currentUser.id).toList();

  // Para el Comando
  List<IncidenteReportado> get incidentosReportados => _allIncidents.where((i) => i.estado == EstadoIncidente.RECIBIDO).toList();
  List<IncidenteReportado> get incidentosDelegados => _allIncidents.where((i) => i.estado != EstadoIncidente.RECIBIDO).toList();

  // Para el Jefe de CAI
  List<IncidenteReportado> get pendientesPorAsignar => _allIncidents.where((i) => 
    i.caiId == currentUser.cai && i.estado == EstadoIncidente.CAI_ASIGNADO).toList();
  
  List<IncidenteReportado> get historialCai => _allIncidents.where((i) => 
    i.caiId == currentUser.cai && (i.estado == EstadoIncidente.AGENTE_ASIGNADO || i.estado == EstadoIncidente.COMPLETADO)).toList();

  // Para el Agente
  List<IncidenteReportado> get misAsignaciones => _allIncidents.where((i) => 
    i.agenteId == currentUser.id && i.estado == EstadoIncidente.AGENTE_ASIGNADO).toList();

  List<IncidenteReportado> get nuevosIncidentes => incidentosReportados;

  // --- ACCIONES DE NEGOCIO ---

  // Simulación de carga inicial desde backend
  Future<void> fetchIncidentes() async {
    isLoading = true;
    // Futuro: _allIncidents = await _incidentService.getAll();
    await Future.delayed(const Duration(seconds: 1));
    isLoading = false;
  }

  // 1. Denunciante crea reporte
  void crearReporte(TipoIncidente tipo) {
    final nuevo = IncidenteReportado(
      id: tipo.id,
      incidente: tipo,
      fechaCreacion: DateTime.now(),
      ubicacion: " ", //proviene del usuario
      detalles: " ", //proviene del usuario
      estado: EstadoIncidente.RECIBIDO,
    );
    _allIncidents.add(nuevo);
    notifyListeners();
  }

  // 2. Comando delega a un CAI
  void delegarACai(String incidentId, String caiId) {
    final index = _allIncidents.indexWhere((i) => i.id == incidentId);
    if (index != -1) {
      _allIncidents[index] = _allIncidents[index].copyWith(
        estado: EstadoIncidente.CAI_ASIGNADO,
        caiId: caiId,
      );
      notifyListeners();
    }
  }

  // 3. Jefe de CAI asigna a un Agente
  void asignarAgente(String incidentId, String agenteId) {
    final index = _allIncidents.indexWhere((i) => i.id == incidentId);
    if (index != -1) {
      _allIncidents[index] = _allIncidents[index].copyWith(
        estado: EstadoIncidente.AGENTE_ASIGNADO,
        agenteId: agenteId,
      );
      notifyListeners();
    }
  }

  // 4. Agente completa el incidente
  void completarIncidente(String incidentId) {
    final index = _allIncidents.indexWhere((i) => i.id == incidentId);
    if (index != -1) {
      _allIncidents[index] = _allIncidents[index].copyWith(
        estado: EstadoIncidente.COMPLETADO,
      );
      notifyListeners();
    }
  }
}