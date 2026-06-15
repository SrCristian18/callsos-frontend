import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:CallSos/data/services/api_exception.dart';

DioException _conTipo(DioExceptionType type) {
  return DioException(requestOptions: RequestOptions(path: '/test'), type: type);
}

DioException _badResponse(int status, dynamic data) {
  final options = RequestOptions(path: '/test');
  final response = Response(requestOptions: options, statusCode: status, data: data);
  return DioException(
    requestOptions: options,
    response: response,
    type: DioExceptionType.badResponse,
  );
}

void main() {
  group('ApiException.fromDioException — backend no responde', () {
    test('connectionTimeout / sendTimeout / receiveTimeout -> timeout', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        final e = ApiException.fromDioException(_conTipo(type));
        expect(e.type, ApiExceptionType.timeout);
        expect(e.message, isNotEmpty);
      }
    });

    test('connectionError -> noConnection', () {
      final e = ApiException.fromDioException(_conTipo(DioExceptionType.connectionError));
      expect(e.type, ApiExceptionType.noConnection);
      expect(e.message, isNotEmpty);
    });

    test('unknown (sin response, sin red) -> noConnection', () {
      final e = ApiException.fromDioException(_conTipo(DioExceptionType.unknown));
      expect(e.type, ApiExceptionType.noConnection);
    });
  });

  group('ApiException.fromDioException — respuestas HTTP (ProblemDetail)', () {
    test('400 con detail de validación -> badRequest', () {
      final e = ApiException.fromDioException(_badResponse(400, {
        'title': 'Error de validación',
        'status': 400,
        'detail': 'descripcion: La descripción es obligatoria',
      }));
      expect(e.type, ApiExceptionType.badRequest);
      expect(e.statusCode, 400);
      expect(e.message, 'descripcion: La descripción es obligatoria');
    });

    test('401 -> unauthorized', () {
      final e = ApiException.fromDioException(_badResponse(401, null));
      expect(e.type, ApiExceptionType.unauthorized);
      expect(e.statusCode, 401);
      expect(e.message, isNotEmpty);
    });

    test('403 -> forbidden', () {
      final e = ApiException.fromDioException(_badResponse(403, null));
      expect(e.type, ApiExceptionType.forbidden);
      expect(e.statusCode, 403);
    });

    test('404 con detail -> notFound, usa el detail como mensaje', () {
      final e = ApiException.fromDioException(_badResponse(404, {
        'title': 'Recurso no encontrado',
        'status': 404,
        'detail': 'Incidente no encontrado: abc-123',
      }));
      expect(e.type, ApiExceptionType.notFound);
      expect(e.statusCode, 404);
      expect(e.message, 'Incidente no encontrado: abc-123');
    });

    test('422 -> businessRule (transición de estado inválida)', () {
      final e = ApiException.fromDioException(_badResponse(422, {
        'title': 'Regla de negocio violada',
        'status': 422,
        'detail': 'No se puede atender un incidente sin agente asignado',
      }));
      expect(e.type, ApiExceptionType.businessRule);
      expect(e.statusCode, 422);
      expect(e.message, 'No se puede atender un incidente sin agente asignado');
    });

    test('500 -> server', () {
      final e = ApiException.fromDioException(_badResponse(500, {
        'title': 'Error interno',
        'status': 500,
        'detail': 'Error interno del servidor. Por favor intente más tarde.',
      }));
      expect(e.type, ApiExceptionType.server);
      expect(e.statusCode, 500);
    });

    test('código HTTP no mapeado explícitamente -> unknown', () {
      final e = ApiException.fromDioException(_badResponse(418, null));
      expect(e.type, ApiExceptionType.unknown);
      expect(e.statusCode, 418);
    });

    test('respuesta sin body (data == null) usa mensaje genérico, no crashea', () {
      final e = ApiException.fromDioException(_badResponse(404, null));
      expect(e.type, ApiExceptionType.notFound);
      expect(e.message, isNotEmpty);
    });
  });
}