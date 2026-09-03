import '../models/agente_disponible.dart';
import '../models/invitacion_agente.dart';
import 'api_client.dart';

/// Servicio de recursos de CAI — espejo de `CaiController`
/// (`/api/v1/cais`) e `InvitacionController` (`/api/v1/invitaciones`).
///
/// FIX Gap 3 (deuda_backend.md): expone el listado real de agentes
/// disponibles de un CAI, y ahora también la generación de tokens de
/// invitación que Comando usa para autorizar el registro de un agente.
///
/// Épica 8 (hallazgo #5): agrega [registrarTokenFcm] — el backend ya
/// tenía `PATCH /cais/{id}/token` desde Épica 5
/// (`RegistrarTokenFcmUnidadService`), pero ningún cliente lo llamaba.
abstract class ICaiService {
  /// `GET /cais/{caiId}/agentes/disponibles` — agentes en estado
  /// DISPONIBLE dentro del CAI indicado.
  Future<List<AgenteDisponible>> agentesDisponibles(String caiId);

  /// `POST /invitaciones` — solo COMANDO. Genera un token de invitación
  /// de un solo uso, atado al CAI indicado, para que un agente se
  /// registre (`SesionViewModel.registrarAgente`).
  Future<InvitacionAgente> generarInvitacion(String unidadPolicialId);

  /// `PATCH /cais/{unidadPolicialId}/token` — registra/actualiza el
  /// token FCM del CAI/unidad policial para notificaciones push (Épica
  /// 8, hallazgo #5).
  ///
  /// IMPORTANTE — ownership (ver `CaiController.java`): el backend
  /// valida que el `actorId` del JWT (OPERADOR_CAI autenticado) coincida
  /// con el `{id}` del path; si no coinciden devuelve `403 Forbidden`.
  /// Por convención, el `actorId` de un OPERADOR_CAI ES el
  /// `unidadPolicialId` de su propio CAI (mismo criterio ya usado en el
  /// hallazgo #3 de esta auditoría, `CaiController.agentesDisponibles`).
  /// [unidadPolicialId] debe ser siempre `SesionViewModel.actorId` del
  /// operador autenticado, nunca un id arbitrario.
  Future<void> registrarTokenFcm({
    required String unidadPolicialId,
    required String tokenFcm,
  });
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

  @override
  Future<void> registrarTokenFcm({
    required String unidadPolicialId,
    required String tokenFcm,
  }) async {
    await _client.patch(
      '/cais/$unidadPolicialId/token',
      data: {'tokenFcm': tokenFcm},
    );
  }
}