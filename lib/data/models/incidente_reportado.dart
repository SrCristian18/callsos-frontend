import 'package:CallSos/data/models/tipo_incidente.dart';
import 'package:CallSos/data/models/enums/estado_incidente.dart';

class IncidenteReportado {
  final String id;
  final TipoIncidente incidente;
  final DateTime fechaCreacion;
  final String ubicacion;
  final String? detalles;
  final EstadoIncidente estado;

  IncidenteReportado({
    required this.id,
    required this.incidente,
    required this.fechaCreacion,
    required this.ubicacion,
    this.detalles,
    required this.estado
  });
}