import 'package:CallSos/data/models/incident_type.dart';
import 'package:flutter/material.dart';
import 'package:CallSos/data/models/role.dart';
import 'package:CallSos/data/models/incident.dart';

class IncidentViewModel extends ChangeNotifier {
  // Simulación de usuario actual (Esto vendría de tu LoginViewModel)
  //manejo de reportes

final List<IncidentType> catalogTypes = [
  IncidentType(id: '1', title: "Robo", icon: Icons.warning, color: Colors.red),
  IncidentType(id: '2', title: "Accidente", icon: Icons.car_crash, color: Colors.orange),
  IncidentType(id: '3', title: "Riña", icon: Icons.people, color: Colors.brown),
  IncidentType(id: '4', title: "Ruido", icon: Icons.volume_up, color: Colors.blue),
  IncidentType(id: '5', title: "Incendio", icon: Icons.local_fire_department, color: Colors.deepOrange),
];

  //manejo de incidentes
  Role currentUserRole = Role.COMANDO; 
  String? currentCaiId = "CAI_SF"; // Solo si es Jefe o Agente

  final List<Incident> allIncidents = [
    Incident(id: "1", title: "Robo", description: "Asalto a mano armada", location: "SF", createdAt: DateTime.timestamp()),
  ];

  List<Incident> get filteredIncidents {
    switch (currentUserRole) {
      case Role.COMANDO:
        return allIncidents.where((i) => i.status == IncidentStatus.RECIBIDO).toList();
      case Role.JEFECAI:
        return allIncidents.where((i) => i.caiId == currentCaiId && i.status == IncidentStatus.CAI_ASIGNADO).toList();
      case Role.AGENTE_POLICIA:
        return allIncidents.where((i) => i.agenteId == "AGENTE_007").toList();
      default:
        return [];
    }
  }

  get incidentTypes => null;

  // Lógica de negocio: Comando autoriza CAI
  void assignToCai(String incidentId, String caiId, String location) {
    int index = allIncidents.indexWhere((i) => i.id == incidentId);
    allIncidents[index] = Incident(
      id: allIncidents[index].id,
      title: allIncidents[index].title,
      description: allIncidents[index].description,
      createdAt: allIncidents[index].createdAt,
      status: IncidentStatus.CAI_ASIGNADO,
      caiId: caiId, 
      location: location,
    );
    notifyListeners();
  }
}