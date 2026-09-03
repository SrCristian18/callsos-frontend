import 'api_client.dart';

/// Servicio del agente — espejo de `AgenteController`
/// (`/api/v1/agentes`).
///
/// Épica 8 (hallazgo #5): antes de este fix no existía ningún servicio
/// dedicado al recurso Agente en el frontend. El backend ya exponía
/// `PATCH /agentes/{id}/token` desde Épica 5
/// (`RegistrarTokenFcmAgenteService`/`AgenteController`), pero ningún
/// cliente del frontend lo llamaba — `NotificacionService` estaba
/// hardcodeado contra `IDenuncianteService` únicamente. Este servicio
/// sigue el MISMO patrón exacto que `DenuncianteService`/`CaiService`
/// (uno por Controller del backend), consistente con el resto del
/// proyecto — se prefirió crear este archivo nuevo en vez de agregar el
/// método a `IncidenteService`, que es espejo estricto de
/// `IncidenteController` (`/api/v1/incidentes`) y no toca `/agentes`.
abstract class IAgenteService {
  /// `PATCH /agentes/{actorId}/token` — registra/actualiza el token FCM
  /// del agente para notificaciones push (Épica 8, hallazgo #5).
  ///
  /// IMPORTANTE — ownership (ver `AgenteController.java`): el backend
  /// valida que el `actorId` del JWT (agente autenticado) coincida con
  /// el `{id}` del path; si no coinciden devuelve `403 Forbidden`
  /// (`ApiExceptionType.forbidden`). [actorId] debe ser siempre el del
  /// usuario autenticado actual (`SesionViewModel.actorId`), nunca un id
  /// arbitrario.
  Future<void> registrarTokenFcm({
    required String actorId,
    required String tokenFcm,
  });
}

class AgenteService implements IAgenteService {
  final IApiClient _client;

  const AgenteService(this._client);

  @override
  Future<void> registrarTokenFcm({
    required String actorId,
    required String tokenFcm,
  }) async {
    await _client.patch(
      '/agentes/$actorId/token',
      data: {'tokenFcm': tokenFcm},
    );
  }
}