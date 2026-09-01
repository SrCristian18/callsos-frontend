import '../models/auditoria_incidente.dart';
import 'api_client.dart';

/// Servicio de auditoría — espejo de `AuditoriaController`
/// (`/api/v1/auditoria`).
///
/// EPIC-07 — Auditorías e historiales (Timeline).
///
/// Solo lectura: expone el historial ya construido y ya filtrado por
/// actor en el backend (`AuditoriaController.historial()` — DENUNCIANTE
/// solo ve el suyo, AGENTE solo el de su asignación real, OPERADOR_CAI
/// solo el de su unidad, COMANDO ve todo). Este servicio no duplica esa
/// lógica de autorización ni la reimplementa del lado del cliente: se
/// limita a llamar al endpoint y mapear la respuesta — si el actor no
/// está autorizado, el backend responde 403 y [ApiClient] lo traduce a
/// una [ApiException] de tipo `forbidden`, igual que el resto de la app.
abstract class IAuditoriaService {
  /// `GET /auditoria/incidente/{id}` — historial completo del incidente,
  /// ya autorizado y filtrado por el backend según el rol del actor
  /// autenticado. Ordenado cronológicamente (más antiguo primero).
  Future<List<AuditoriaIncidente>> historial(String incidenteId);
}

class AuditoriaService implements IAuditoriaService {
  final IApiClient _client;

  const AuditoriaService(this._client);

  @override
  Future<List<AuditoriaIncidente>> historial(String incidenteId) async {
    final data = await _client.get('/auditoria/incidente/$incidenteId');
    return (data as List<dynamic>)
        .map((e) => AuditoriaIncidente.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}