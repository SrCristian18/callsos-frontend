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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'incidenteId': incidente.id,
      'fechaCreacion': fechaCreacion.toIso8601String(),
      'ubicacion': ubicacion,
      'detalles': detalles,
      'estado': estado.name,
      'caiId': caiId,
      'agenteId': agenteId,
    };
  }

  factory IncidenteReportado.fromMap(Map<String, dynamic> map, TipoIncidente tipo) {
    return IncidenteReportado(
      id: map['id'],
      incidente: tipo,
      fechaCreacion: DateTime.parse(map['fechaCreacion']),
      ubicacion: map['ubicacion'],
      detalles: map['detalles'],
      estado: EstadoIncidente.values.byName(map['estado']),
      caiId: map['caiId'],
      agenteId: map['agenteId'],
    );
  }
}