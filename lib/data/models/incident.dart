class Incident {
  final String id;
  final String title;
  final String description;
  final String location;
  final DateTime createdAt;
  final String? caiId;
  final String? agenteId;
  final IncidentStatus status;

  Incident({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.createdAt,
    this.caiId,
    this.agenteId,
    this.status = IncidentStatus.RECIBIDO,
  });
}

enum IncidentStatus {
  RECIBIDO, 
  CAI_ASIGNADO, 
  AGENTE_ASIGNADO, 
  EN_PROCESO, 
  COMPLETADO
}