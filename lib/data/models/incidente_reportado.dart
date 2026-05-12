import 'package:CallSos/data/models/tipo_incidente.dart';
import 'package:CallSos/data/models/enums/estado_incidente.dart';

class IncidenteReportado {
  final String id;
  final TipoIncidente incidente;
  final DateTime fechaCreacion;
  final String ubicacion;
  final String? detalles;
  final EstadoIncidente estado;
  final String? caiId;
  final String? agenteId;

  IncidenteReportado({
    required this.id,
    required this.incidente,
    required this.fechaCreacion,
    required this.ubicacion,
    this.detalles,
    required this.estado,
    this.caiId,
    this.agenteId,
  });

// --- EL MÉTODO COPYWITH ---
  IncidenteReportado copyWith({
    String? id,
    TipoIncidente? incidente,
    DateTime? fechaCreacion,
    String? ubicacion,
    String? detalles,
    EstadoIncidente? estado,
    String? caiId,
    String? agenteId,
  }) {
    return IncidenteReportado(
      id: id ?? this.id,
      incidente: incidente ?? this.incidente,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      ubicacion: ubicacion ?? this.ubicacion,
      detalles: detalles ?? this.detalles,
      estado: estado ?? this.estado,
      caiId: caiId ?? this.caiId,
      agenteId: agenteId ?? this.agenteId,
    );
  }
}