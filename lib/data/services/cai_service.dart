import '../models/agente_disponible.dart';
import '../models/invitacion_agente.dart';
import 'api_client.dart';

/// Servicio de recursos de CAI — espejo de `CaiController`
/// (`/api/v1/cais`) e `InvitacionController` (`/api/v1/invitaciones`).
///
/// FIX Gap 3 (deuda_backend.md): expone el listado real de agentes
/// disponibles de un CAI, y ahora también la generación de tokens de
/// invitación que Comando usa para autorizar el registro de un agente.
abstract class ICaiService {
  /// `GET /cais/{caiId}/agentes/disponibles` — agentes en estado
  /// DISPONIBLE dentro del CAI indicado.
  Future<List<AgenteDisponible>> agentesDisponibles(String caiId);

  /// `POST /invitaciones` — solo COMANDO. Genera un token de invitación
  /// de un solo uso, atado al CAI indicado, para que un agente se
  /// registre (`SesionViewModel.registrarAgente`).
  Future<InvitacionAgente> generarInvitacion(String unidadPolicialId);
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

  @override
  Future<InvitacionAgente> generarInvitacion(String unidadPolicialId) async {
    final data = await _client.post(
      '/invitaciones',
      data: {'unidadPolicialId': unidadPolicialId},
    );
    return InvitacionAgente.fromJson(data as Map<String, dynamic>);
  }
}