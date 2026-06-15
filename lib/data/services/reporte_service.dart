import 'api_client.dart';

/// Resultado de `POST /reportes/hallazgos`, espejo del record
/// `ReporteController.ReporteHallazgosResponse`
/// (`{id, fecha, incidenteId, agenteId}`).
class ReporteHallazgosResult {
  final String id;
  final DateTime fecha;
  final String incidenteId;
  final String agenteId;

  const ReporteHallazgosResult({
    required this.id,
    required this.fecha,
    required this.incidenteId,
    required this.agenteId,
  });

  factory ReporteHallazgosResult.fromJson(Map<String, dynamic> json) {
    return ReporteHallazgosResult(
      id: json['id'] as String,
      // NOTA: `fecha` es un `LocalDateTime` (Java) — Spring Boot lo
      // serializa por defecto como string ISO-8601 (ej.
      // "2026-06-14T10:30:00"), parseable directamente con DateTime.parse.
      // A validar contra una respuesta real del backend al integrar (F.4).
      fecha: DateTime.parse(json['fecha'] as String),
      incidenteId: json['incidenteId'] as String,
      agenteId: json['agenteId'] as String,
    );
  }
}

/// Resultado de `POST /reportes/administrativo`, espejo del record
/// `ReporteController.ReporteAdministrativoResponse`
/// (`{id, fecha, incidenteId, autoridadId}`).
class ReporteAdministrativoResult {
  final String id;
  final DateTime fecha;
  final String incidenteId;
  final String autoridadId;

  const ReporteAdministrativoResult({
    required this.id,
    required this.fecha,
    required this.incidenteId,
    required this.autoridadId,
  });

  factory ReporteAdministrativoResult.fromJson(Map<String, dynamic> json) {
    return ReporteAdministrativoResult(
      id: json['id'] as String,
      fecha: DateTime.parse(json['fecha'] as String),
      incidenteId: json['incidenteId'] as String,
      autoridadId: json['autoridadId'] as String,
    );
  }
}

/// Servicio de reportes — espejo de `ReporteController`
/// (`/api/v1/reportes`).
///
/// F.0.3 — Capa de red.
abstract class IReporteService {
  /// `POST /reportes/hallazgos` — el agente reporta hallazgos al finalizar
  /// la atención (F.4 — ReporteHallazgosView).
  Future<ReporteHallazgosResult> crearHallazgos({
    required String incidenteId,
    required String agenteId,
    required String descripcion,
  });

  /// `POST /reportes/administrativo` — Comando/Operador CAI genera un
  /// reporte administrativo sobre un incidente.
  Future<ReporteAdministrativoResult> crearAdministrativo({
    required String incidenteId,
    required String autoridadId,
    required String resumen,
  });
}

class ReporteService implements IReporteService {
  final IApiClient _client;

  const ReporteService(this._client);

  @override
  Future<ReporteHallazgosResult> crearHallazgos({
    required String incidenteId,
    required String agenteId,
    required String descripcion,
  }) async {
    final data = await _client.post(
      '/reportes/hallazgos',
      data: {
        'incidenteId': incidenteId,
        'agenteId': agenteId,
        'descripcion': descripcion,
      },
    );
    return ReporteHallazgosResult.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<ReporteAdministrativoResult> crearAdministrativo({
    required String incidenteId,
    required String autoridadId,
    required String resumen,
  }) async {
    final data = await _client.post(
      '/reportes/administrativo',
      data: {
        'incidenteId': incidenteId,
        'autoridadId': autoridadId,
        'resumen': resumen,
      },
    );
    return ReporteAdministrativoResult.fromJson(data as Map<String, dynamic>);
  }
}