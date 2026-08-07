import 'package:dio/dio.dart';

/// Categorías de error de la capa de red.
///
/// F.0.3 — Capa de red.
///
/// Cada valor corresponde a una situación que la UI necesita distinguir
/// para reaccionar apropiadamente (mostrar mensaje, forzar logout,
/// reintentar, etc.). El mapeo HTTP -> tipo está alineado con
/// `GlobalExceptionHandler` del backend:
///
/// | HTTP | Origen en el backend                          | Tipo aquí       |
/// |------|------------------------------------------------|-----------------|
/// | 400  | `MethodArgumentNotValidException` (`@Valid`)    | [badRequest]    |
/// | 401  | JWT ausente/inválido/expirado (Spring Security) | [unauthorized]  |
/// | 403  | Autenticado pero sin permiso sobre el recurso   | [forbidden]     |
/// | 404  | `IllegalArgumentException` (recurso no existe)  | [notFound]      |
/// | 422  | `IllegalStateException` (regla de negocio /     | [businessRule]  |
/// |      | transición de estado inválida)                  |                 |
/// | 5xx  | `Exception` genérica no controlada              | [server]        |
/// | —    | timeout de conexión/envío/recepción             | [timeout]       |
/// | —    | sin red / DNS / servidor caído                  | [noConnection]  |
enum ApiExceptionType {
  badRequest,
  unauthorized,
  forbidden,
  notFound,
  businessRule,
  server,
  timeout,
  noConnection,
  unknown,
}

/// Excepción de dominio para errores de red/API.
///
/// Todas las llamadas a través de [ApiClient] que fallen lanzan
/// **siempre** una [ApiException] (nunca un [DioException] crudo), de modo
/// que la UI y los ViewModels solo necesitan conocer este tipo.
///
/// [message] es un texto ya apto para mostrar al usuario: si el backend
/// devolvió un `ProblemDetail` (RFC 7807) con campo `detail`, se usa ese
/// texto (por ejemplo, "Incidente no encontrado: abc-123" o el detalle de
/// validación "descripcion: La descripción es obligatoria"); si no, se usa
/// un mensaje genérico apropiado para [type].
class ApiException implements Exception {
  final ApiExceptionType type;
  final String message;
  final int? statusCode;

  const ApiException({
    required this.type,
    required this.message,
    this.statusCode,
  });

  /// Construye una [ApiException] a partir de un [DioException].
  ///
  /// Maneja explícitamente el caso "backend no responde" (timeouts y
  /// errores de conexión) con mensajes orientados al usuario, sin dejar
  /// que la excepción cruda de Dio se propague y tumbe la app
  /// (criterio de terminado de F.0.3).
  factory ApiException.fromDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
          type: ApiExceptionType.timeout,
          message:
              'El servidor tardó demasiado en responder. '
              'Verifica tu conexión e inténtalo de nuevo.',
        );

      case DioExceptionType.connectionError:
        return const ApiException(
          type: ApiExceptionType.noConnection,
          message:
              'No se pudo conectar con el servidor. '
              'Verifica tu conexión a internet e inténtalo de nuevo.',
        );

      case DioExceptionType.badResponse:
        return _fromResponse(e);

      case DioExceptionType.cancel:
        return const ApiException(
          type: ApiExceptionType.unknown,
          message: 'La solicitud fue cancelada.',
        );

      case DioExceptionType.badCertificate:
        return const ApiException(
          type: ApiExceptionType.unknown,
          message: 'No se pudo verificar la seguridad de la conexión.',
        );

      case DioExceptionType.unknown:
        // Suele ocurrir cuando no hay red en absoluto (SocketException
        // antes de que Dio llegue a clasificarlo como connectionError).
        return const ApiException(
          type: ApiExceptionType.noConnection,
          message:
              'No se pudo conectar con el servidor. '
              'Verifica tu conexión a internet e inténtalo de nuevo.',
        );
      case DioExceptionType.transformTimeout:
        // TODO: Handle this case.
        throw UnimplementedError();
    }
  }

  static ApiException _fromResponse(DioException e) {
    final status = e.response?.statusCode;
    final detail = _extraerDetail(e.response?.data);

    switch (status) {
      case 400:
        return ApiException(
          type: ApiExceptionType.badRequest,
          statusCode: status,
          message: detail ?? 'Los datos enviados no son válidos.',
        );

      case 401:
        return ApiException(
          type: ApiExceptionType.unauthorized,
          statusCode: status,
          message: detail ??
              'Tu sesión expiró o no es válida. Inicia sesión nuevamente.',
        );

      case 403:
        return ApiException(
          type: ApiExceptionType.forbidden,
          statusCode: status,
          message: detail ?? 'No tienes permisos para realizar esta acción.',
        );

      case 404:
        return ApiException(
          type: ApiExceptionType.notFound,
          statusCode: status,
          message: detail ?? 'El recurso solicitado no existe.',
        );

      case 422:
        return ApiException(
          type: ApiExceptionType.businessRule,
          statusCode: status,
          message: detail ??
              'La operación no es válida en el estado actual del incidente.',
        );

      default:
        if (status != null && status >= 500) {
          return ApiException(
            type: ApiExceptionType.server,
            statusCode: status,
            message: detail ??
                'Ocurrió un error interno en el servidor. '
                    'Intenta más tarde.',
          );
        }
        return ApiException(
          type: ApiExceptionType.unknown,
          statusCode: status,
          message: detail ?? 'Ocurrió un error inesperado (HTTP $status).',
        );
    }
  }

  /// Extrae el campo `detail` de un `ProblemDetail` (RFC 7807), si el
  /// cuerpo de la respuesta tiene esa forma.
  ///
  /// Ejemplo de respuesta del backend (`GlobalExceptionHandler`):
  /// ```json
  /// {
  ///   "type": "about:blank",
  ///   "title": "Recurso no encontrado",
  ///   "status": 404,
  ///   "detail": "Incidente no encontrado: abc-123",
  ///   "instance": "/api/v1/incidentes/abc-123",
  ///   "timestamp": "2026-06-14T10:00:00Z"
  /// }
  /// ```
  static String? _extraerDetail(dynamic data) {
    if (data is Map && data['detail'] is String) {
      final detail = data['detail'] as String;
      return detail.isNotEmpty ? detail : null;
    }
    return null;
  }

  @override
  String toString() {
    final code = statusCode != null ? ', HTTP $statusCode' : '';
    return 'ApiException(${type.name}$code): $message';
  }
}