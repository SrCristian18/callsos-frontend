import '../models/agente_disponible.dart';
import 'api_client.dart';

/// Servicio de recursos de CAI — espejo de `CaiController`
/// (`/api/v1/cais`).
///
/// FIX Gap 3 (deuda_backend.md): expone el listado real de agentes
/// disponibles de un CAI, que antes solo existía como lógica interna
/// de auto-asignación en el backend.
abstract class ICaiService {
  /// `GET /cais/{caiId}/agentes/disponibles` — agentes en estado
  /// DISPONIBLE dentro del CAI indicado.
  Future<List<AgenteDisponible>> agentesDisponibles(String caiId);
}

class CaiService implements ICaiService {
  final IApiClient _client;

  const CaiService(this._client);

  @override
  Future<List<AgenteDisponible>> agentesDisponibles(String caiId) async {
    final data = await _client.get('/cais/$caiId/agentes/disponibles');
    return (data as List<dynamic>)
        .map((e) => AgenteDisponible.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}