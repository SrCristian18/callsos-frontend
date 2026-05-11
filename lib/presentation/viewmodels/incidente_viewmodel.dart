import 'package:CallSos/data/models/enums/estado_incidente.dart';
import 'package:CallSos/data/models/incidente_reportado.dart';
import 'package:CallSos/data/models/tipo_incidente.dart';
import 'package:flutter/material.dart';

class IncidenteViewModel extends ChangeNotifier {
  int currentIndex = 0;

  final List<TipoIncidente> incidentes = [
    TipoIncidente(
      id: "1",
      titulo: "Ruido excesivo",
      descripcion: "Problemas de contaminación sonora",
      icono: Icons.volume_up_rounded,
      color: Colors.pinkAccent,
    ),
    TipoIncidente(
      id: "2",
      titulo: "Abuso infantil",
      descripcion: "Violencia o maltrato contra menores",
      icono: Icons.child_care,
      color: Colors.orange,
    ),
    TipoIncidente(
      id: "3",
      titulo: "Incidente de tránsito",
      descripcion: "Accidente o siniestro vial",
      icono: Icons.traffic,
      color: Colors.blue,
    ),
    TipoIncidente(
      id: "4",
      titulo: "Riñas o peleas",
      descripcion: "Conflictos físicos entre personas",
      icono: Icons.groups,
      color: Colors.green,
    ),
    TipoIncidente(
      id: "5",
      titulo: "Violencia doméstica",
      descripcion: "Agresión en el entorno familiar",
      icono: Icons.favorite,
      color: Colors.purple,
    ),
    TipoIncidente(
      id: "6",
      titulo: "Robos o asaltos",
      descripcion: "Delito de hurto o atraco",
      icono: Icons.gpp_bad,
      color: Colors.red,
    ),
  ];

  final List<IncidenteReportado> reportados = [];

  void changeTab(int index) {
    currentIndex = index;
    notifyListeners();
  }

  void agregarReporte(TipoIncidente incidente) {
    reportados.add(
      IncidenteReportado(
        id: "",
        incidente: incidente,
        fechaCreacion: DateTime.now(),
        ubicacion: "",
        detalles: "",
        estado: EstadoIncidente.RECIBIDO,
        ),
    );

    notifyListeners();
  }

  void eliminarReporte(String id) {
    reportados.removeWhere((e) => e.id == id);
    notifyListeners();
  }
}