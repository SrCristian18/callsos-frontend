import 'api_client.dart';

/// Servicio del denunciante — espejo de `DenuncianteController`
/// (`/api/v1/denunciantes`).
///
/// F.0.3 — Capa de red.
abstract class IDenuncianteService {
  /// `PATCH /denunciantes/{actorId}/token` — registra/actualiza el token
  /// FCM del denunciante para notificaciones push (F.5).
  ///
  /// IMPORTANTE — ownership (ver `DenuncianteController.java`): el backend
  /// valida que el `actorId` del JWT (denunciante autenticado) coincida con
  /// el `{id}` del path; si no coinciden devuelve `403 Forbidden`
  /// (`ApiExceptionType.forbidden`). [actorId] debe ser siempre el del
  /// usuario autenticado actual (`SesionViewModel.actorId`, F.0.4), nunca
  /// un id arbitrario.
  Future<void> registrarTokenFcm({
    required String actorId,
    required String tokenFcm,
  });
}

class DenuncianteService implements IDenuncianteService {
  final IApiClient _client;

  const DenuncianteService(this._client);

  @override
  Future<void> registrarTokenFcm({
    required String actorId,
    required String tokenFcm,
  }) async {
    await _client.patch(
      '/denunciantes/$actorId/token',
      data: {'tokenFcm': tokenFcm},
    );
  }
}