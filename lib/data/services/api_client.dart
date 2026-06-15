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

  ApiClient({Dio? dio, this.tokenProvider})
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
      ),
    );

    if (AppConfig.isDebug) {
      _dio.interceptors.add(
        LogInterceptor(requestBody: true, responseBody: true),
      );
    }
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