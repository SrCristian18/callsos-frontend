/// Proveedor del token JWT actual para inyectarlo en las peticiones HTTP.
///
/// F.0.3 — Capa de red.
///
/// [ApiClient] necesita el JWT para el header `Authorization: Bearer <token>`,
/// pero F.0.3 se implementa ANTES que F.0.4 (gestión de sesión), y no debe
/// depender de `SesionViewModel` directamente (la capa de datos no debe
/// depender de la capa de presentación).
///
/// Esta interfaz rompe esa dependencia: [ApiClient] solo conoce
/// [ITokenProvider]. En F.0.4, `SesionViewModel` implementará esta interfaz
/// (`class SesionViewModel extends ChangeNotifier implements ITokenProvider`)
/// y `AppProviders` conectará `apiClient.tokenProvider = sesionViewModel`.
///
/// Mientras F.0.4 no exista, [ApiClient.tokenProvider] puede dejarse en
/// `null` (sin header `Authorization`) — suficiente para probar el endpoint
/// público `POST /auth/login`.
abstract class ITokenProvider {
  /// El JWT actual, o `null` si no hay sesión activa.
  String? get token;
}