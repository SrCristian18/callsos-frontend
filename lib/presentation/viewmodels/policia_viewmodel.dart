import 'package:flutter/material.dart';
import 'package:CallSos/data/models/incident_cai_model.dart';
import 'package:CallSos/data/models/agente_model.dart';
import 'package:CallSos/data/models/cai_model.dart';

class PoliciaViewModel extends ChangeNotifier {
  // Simulamos datos que vendrían del Back-end
  final Agente _agenteLogueado = Agente(id: "A1", nombre: "Oficial Murillo", rango: "Sargento", caiId: "CAI_01");
  final Cai _caiActual = Cai(id: "CAI_01", nombre: "CAI San Francisco", direccion: "Calle 4 #12");

  // Lista global de incidentes (de todos los CAIs)
  final List<Incidente> _todosLosIncidentes = [
    Incidente(id: "1", titulo: "Riña callejera", descripcion: "Parque principal", icono: Icons.fitness_center, color: Colors.red, caiId: "CAI_01"),
    Incidente(id: "2", titulo: "Ruido excesivo", descripcion: "Bar El Cruce", icono: Icons.volume_up, color: Colors.orange, caiId: "CAI_01"),
    Incidente(id: "3", titulo: "Accidente", descripcion: "Av. Santander", icono: Icons.car_crash, color: Colors.blue, caiId: "CAI_02"), // Este no debería verse
  ];

  // Getters
  Agente get agente => _agenteLogueado;
  Cai get cai => _caiActual;

  // Filtramos los incidentes: Solo los del CAI del agente y por estado
  List<Incidente> get incidentesPendientes => _todosLosIncidentes
      .where((i) => i.caiId == _agenteLogueado.caiId && i.estado == EstadoIncidente.pendiente)
      .toList();

  List<Incidente> get incidentesCompletados => _todosLosIncidentes
      .where((i) => i.caiId == _agenteLogueado.caiId && i.estado == EstadoIncidente.completado)
      .toList();
}