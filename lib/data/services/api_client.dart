import 'package:dio/dio.dart';

import '../../core/app_config.dart';
import 'api_exception.dart';
import 'token_provider.dart';

/// Contrato mínimo de cliente HTTP que consumen los servicios
/// (`AuthService`, `IncidenteService`, etc.).
///
/// F.0.3 — Capa de red.
///
/// Se define como interfaz para que F.7 pueda mockearla con `mocktail`
/// (`class MockApiClient extends Mock implements IApiClient`) sin depender
/// de `Dio` en los tests de servicios/ViewModels.
///
/// Los métodos devuelven `dynamic` porque el cuerpo de la respuesta puede
/// ser un `Map` (objeto JSON), un `List` (colección), un `String` (por
/// ejemplo `GET /incidentes/{id}/estado`, que el backend serializa como
/// `"CREADO"`), o `null` (respuestas `204 No Content` de las transiciones
/// de estado). Cada servicio sabe qué forma esperar y hace el cast
/// correspondiente.
///
/// IMPORTANTE: las implementaciones NUNCA deben dejar escapar un
/// [DioException] — siempre deben traducirlo a [ApiException]
/// (ver [ApiException.fromDioException]).
abstract class IApiClient {
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters});

  Future<dynamic> post(String path, {dynamic data});

  Future<dynamic> patch(String path, {dynamic data});
}

/// Implementación de [IApiClient] sobre `Dio`.
///
/// - `baseUrl` = [AppConfig.apiV1] (`http://<host>:<puerto>/api/v1`), por lo
///   que cada servicio usa rutas relativas (`/auth/login`,
///   `/incidentes/mis-incidentes`, etc.).
/// - Interceptor de request: si [tokenProvider] tiene un token, agrega
///   `Authorization: Bearer <token>` a cada petición.
/// - Interceptor de error (Épica 8, hallazgo #7): detecta un `401` en
///   CUALQUIER petición autenticada (no el intento de login en sí) y
///   dispara [onSesionInvalida] — ver docstring de ese campo.
/// - Interceptor de logging (solo si [AppConfig.isDebug]).
/// - Todas las excepciones de Dio (timeouts, sin conexión, HTTP 4xx/5xx) se
///   capturan y se relanzan como [ApiException] — la app nunca se cae por
///   un error de red no controlado.
class ApiClient implements IApiClient {
  final Dio _dio;

  /// Proveedor del JWT actual (ver [ITokenProvider]).
  ///
  /// Se deja mutable (no `final`, asignable después de construir el
  /// cliente) porque en `AppProviders` el `ApiClient` se crea ANTES que
  /// `SesionViewModel` (que lo implementará en F.0.4) — se conecta luego
  /// con `apiClient.tokenProvider = sesionViewModel`.
  ITokenProvider? tokenProvider;

  /// Épica 8 (hallazgo #7): se invoca cuando el interceptor de error
  /// detecta un `401 Unauthorized` en una petición que NO es el intento
  /// de login (`POST /auth/login`) — es decir, una sesión que YA estaba
  /// activa dejó de ser válida (JWT expirado, o invalidado del lado del
  /// servidor). ANTES de este fix, ningún interceptor reaccionaba a este
  /// caso: la petición simplemente fallaba con un `ApiException` que cada
  /// pantalla manejaba (o no) por su cuenta, dejando al usuario en una
  /// pantalla rota sin explicación.
  ///
  /// Se deja como callback simple (no un `Stream`) porque solo hay UN
  /// consumidor real (`AppProviders`, que lo conecta a
  /// `SesionViewModel.manejarSesionInvalida` + navegación) — un `Stream`
  /// agregaría ceremonia (`StreamController`, `dispose`) sin necesidad.
  ///
  /// Deliberadamente NO se dispara para `/auth/login`: un 401 ahí es
  /// "contraseña incorrecta" (ver `AuthService.login`), un caso completamente
  /// distinto que YA maneja `SesionViewModel.login` — dispararlo también acá
  /// causaría un loop (login falla -> se "cierra sesión" -> intenta navegar
  /// a la pantalla de login otra vez).
  void Function()? onSesionInvalida;

  ApiClient({Dio? dio, this.tokenProvider, this.onSesionInvalida})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.apiV1,
                connectTimeout:
                    const Duration(milliseconds: AppConfig.httpTimeoutMs),
                receiveTimeout:
                    const Duration(milliseconds: AppConfig.httpTimeoutMs),
                sendTimeout:
                    const Duration(milliseconds: AppConfig.httpTimeoutMs),
                headers: const {'Content-Type': 'application/json'},
              ),
            ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = tokenProvider?.token;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          if (_esSesionInvalida(error)) {
            onSesionInvalida?.call();
          }
          handler.next(error);
        },
      ),
    );

    if (AppConfig.isDebug) {
      _dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true),
      );
    }
  }

  /// `true` si [error] es un `401` en una petición que NO es el propio
  /// intento de login — ver docstring de [onSesionInvalida].
  ///
  /// Compara contra `/auth/login` con `endsWith` (no `==`) porque
  /// `RequestOptions.path` puede venir como ruta relativa (`/auth/login`)
  /// o absoluta (`http://host/api/v1/auth/login`) según cómo Dio la haya
  /// resuelto internamente — `endsWith` cubre ambos casos sin depender de
  /// ese detalle de implementación.
  bool _esSesionInvalida(DioException error) {
    if (error.response?.statusCode != 401) return false;
    final path = error.requestOptions.path;
    return !path.endsWith('/auth/login');
  }

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParameters}) {
    return _request(() => _dio.get(path, queryParameters: queryParameters));
  }

  @override
  Future<dynamic> post(String path, {dynamic data}) {
    return _request(() => _dio.post(path, data: data));
  }

  @override
  Future<dynamic> patch(String path, {dynamic data}) {
    return _request(() => _dio.patch(path, data: data));
  }

  /// Ejecuta la llamada HTTP y traduce cualquier error a [ApiException].
  ///
  /// Este es el único punto de manejo de errores de toda la capa de red:
  /// ningún [DioException] sale de [ApiClient] — se convierte siempre en
  /// [ApiException] (criterio de terminado de F.0.3: "ApiClient maneja el
  /// caso backend no responde sin tumbar la app").
  Future<dynamic> _request(Future<Response<dynamic>> Function() call) async {
    try {
      final response = await call();
      return response.data;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}