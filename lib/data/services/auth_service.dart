import '../models/auth_result.dart';
import 'api_client.dart';
import 'api_exception.dart';

/// Servicio de autenticación — espejo de `AuthController`
/// (`POST /api/v1/auth/login`).
///
/// F.0.3 — Capa de red.
abstract class IAuthService {
  /// Autentica con `username`/`password` y devuelve [AuthResult]
  /// (`{token, actorId, rol}`).
  ///
  /// Lanza [ApiException]:
  /// - `type == ApiExceptionType.unauthorized` si las credenciales son
  ///   inválidas (ver nota en [AuthService.login] sobre el 404 del backend).
  /// - `type == ApiExceptionType.timeout` / `noConnection` si el backend no
  ///   responde.
  Future<AuthResult> login({
    required String username,
    required String password,
  });

  /// Registro abierto de DENUNCIANTE — espejo de
  /// `POST /auth/registro/denunciante`. `documento` funciona como
  /// username (ver nota de diseño en RegistrarDenunciantePort, backend).
  /// Devuelve [AuthResult] igual que [login] — autologueo tras registrar.
  Future<AuthResult> registrarDenunciante({
    required String nombre,
    required String apellido,
    required String documento,
    required String telefono,
    required String password,
    required String confirmarPassword,
  });

  /// Registro de AGENTE mediante token de invitación generado por
  /// Comando — espejo de `POST /auth/registro/agente`. El CAI NUNCA se
  /// envía desde el cliente: sale del token, validado en el backend.
  Future<AuthResult> registrarAgente({
    required String token,
    required String nombre,
    required String telefono,
    required String username,
    required String password,
    required String confirmarPassword,
  });
}

class AuthService implements IAuthService {
  final IApiClient _client;

  const AuthService(this._client);

  @override
  Future<AuthResult> login({
    required String username,
    required String password,
  }) async {
    try {
      final data = await _client.post(
        '/auth/login',
        data: {'username': username, 'password': password},
      );
      return AuthResult.fromJson(data as Map<String, dynamic>);
    } on ApiException catch (e) {
      // NOTA (ver AuthController.java): el backend modela "credenciales
      // inválidas" como IllegalArgumentException -> 404 Not Found
      // ("Recurso no encontrado"), reutilizando el mismo manejador que para
      // "incidente no encontrado", etc. Para la UI de login, un 404 en
      // este endpoint SIEMPRE significa "usuario o contraseña incorrectos",
      // nunca "el endpoint no existe" — lo traducimos a `unauthorized` con
      // un mensaje apto para mostrar directamente en el formulario.
      if (e.type == ApiExceptionType.notFound) {
        throw ApiException(
          type: ApiExceptionType.unauthorized,
          statusCode: e.statusCode,
          message: 'Usuario o contraseña incorrectos.',
        );
      }
      rethrow;
    }
  }

  @override
  Future<AuthResult> registrarDenunciante({
    required String nombre,
    required String apellido,
    required String documento,
    required String telefono,
    required String password,
    required String confirmarPassword,
  }) async {
    // NOTA: el backend modela "documento/username ya registrado" y
    // "contraseñas no coinciden" como IllegalStateException -> 422
    // (ver GlobalExceptionHandler + RegistrarDenuncianteService). ApiClient
    // ya traduce ese 422 a ApiExceptionType.businessRule con e.message
    // legible — no hace falta traducción extra acá, a diferencia de login.
    final data = await _client.post(
      '/auth/registro/denunciante',
      data: {
        'nombre': nombre,
        'apellido': apellido,
        'documento': documento,
        'telefono': telefono,
        'password': password,
        'confirmarPassword': confirmarPassword,
      },
    );
    return AuthResult.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<AuthResult> registrarAgente({
    required String token,
    required String nombre,
    required String telefono,
    required String username,
    required String password,
    required String confirmarPassword,
  }) async {
    final data = await _client.post(
      '/auth/registro/agente',
      data: {
        'token': token,
        'nombre': nombre,
        'telefono': telefono,
        'username': username,
        'password': password,
        'confirmarPassword': confirmarPassword,
      },
    );
    return AuthResult.fromJson(data as Map<String, dynamic>);
  }
}