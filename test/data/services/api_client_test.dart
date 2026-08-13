import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:CallSos/data/services/api_client.dart';
import 'package:CallSos/data/services/api_exception.dart';
import 'package:CallSos/data/services/token_provider.dart';

/// Adaptador HTTP falso e in-memory para probar [ApiClient] de punta a
/// punta (interceptores incluidos) sin hacer red real y sin agregar una
/// dependencia nueva de mocking de Dio al pubspec.
///
/// `_ScriptedAdapter.next` decide qué hace la siguiente llamada:
///   - Si `error` está seteado, lo lanza (simula timeouts, sin conexión, etc.)
///   - Si no, responde con `statusCode`/`body` (Dio mismo decide si eso es
///     un 2xx exitoso o dispara un DioException tipo badResponse, igual
///     que con un servidor real — no se simula ese salto a mano).
class _ScriptedAdapter implements HttpClientAdapter {
  DioException? nextError;
  int nextStatusCode = 200;
  dynamic nextBody = {'ok': true};

  RequestOptions? ultimaRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    ultimaRequest = options;

    if (nextError != null) {
      throw nextError!;
    }

    return ResponseBody.fromString(
      jsonEncode(nextBody),
      nextStatusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _TokenProviderFalso implements ITokenProvider {
  _TokenProviderFalso(this.token);
  @override
  final String? token;
}

void main() {
  late _ScriptedAdapter adapter;
  late Dio dio;

  setUp(() {
    adapter = _ScriptedAdapter();
    dio = Dio(BaseOptions(baseUrl: 'http://test.local/api/v1'))
      ..httpClientAdapter = adapter;
  });

  group('ApiClient — interceptor JWT', () {
    test('agrega Authorization: Bearer <token> cuando tokenProvider tiene token', () async {
      final client = ApiClient(dio: dio, tokenProvider: _TokenProviderFalso('jwt-xyz'));

      await client.get('/incidentes/i-001');

      expect(
        adapter.ultimaRequest!.headers['Authorization'],
        'Bearer jwt-xyz',
      );
    });

    test('NO agrega Authorization cuando tokenProvider es null', () async {
      final client = ApiClient(dio: dio, tokenProvider: null);

      await client.get('/auth/login');

      expect(adapter.ultimaRequest!.headers.containsKey('Authorization'), isFalse);
    });

    test('NO agrega Authorization cuando el token está vacío', () async {
      final client = ApiClient(dio: dio, tokenProvider: _TokenProviderFalso(''));

      await client.get('/auth/login');

      expect(adapter.ultimaRequest!.headers.containsKey('Authorization'), isFalse);
    });

    test('tokenProvider es mutable y se puede conectar después de construir el cliente '
        '(caso real: AppProviders crea ApiClient antes que SesionViewModel)', () async {
      final client = ApiClient(dio: dio, tokenProvider: null);
      await client.get('/auth/login');
      expect(adapter.ultimaRequest!.headers.containsKey('Authorization'), isFalse);

      client.tokenProvider = _TokenProviderFalso('jwt-conectado-despues');
      await client.get('/incidentes/i-001');

      expect(
        adapter.ultimaRequest!.headers['Authorization'],
        'Bearer jwt-conectado-despues',
      );
    });

    test('el token se refleja en tiempo real (mismo tokenProvider, valor cambia entre llamadas)', () async {
      final tokenProvider = _TokenProviderMutable('jwt-viejo');
      final client = ApiClient(dio: dio, tokenProvider: tokenProvider);

      await client.get('/incidentes/i-001');
      expect(adapter.ultimaRequest!.headers['Authorization'], 'Bearer jwt-viejo');

      tokenProvider.token = 'jwt-renovado';
      await client.get('/incidentes/i-002');
      expect(adapter.ultimaRequest!.headers['Authorization'], 'Bearer jwt-renovado');
    });
  });

  group('ApiClient — verbos HTTP delegan correctamente a Dio', () {
    test('get() retorna response.data', () async {
      adapter.nextBody = {'id': 'i-001', 'estado': 'CREADO'};
      final client = ApiClient(dio: dio);

      final data = await client.get('/incidentes/i-001');

      expect(data, {'id': 'i-001', 'estado': 'CREADO'});
    });

    test('get() propaga queryParameters', () async {
      final client = ApiClient(dio: dio);

      await client.get('/incidentes/por-estado', queryParameters: {'estado': 'CREADO'});

      expect(adapter.ultimaRequest!.queryParameters['estado'], 'CREADO');
    });

    test('post() envía el body y retorna response.data', () async {
      adapter.nextBody = {'token': 'jwt-nuevo', 'actorId': 'den-001'};
      final client = ApiClient(dio: dio);

      final data = await client.post('/auth/login', data: {
        'username': 'juan',
        'password': '1234',
      });

      expect(data, {'token': 'jwt-nuevo', 'actorId': 'den-001'});
      expect(adapter.ultimaRequest!.method, 'POST');
    });

    test('patch() usa el verbo PATCH', () async {
      adapter.nextStatusCode = 204;
      adapter.nextBody = '';
      final client = ApiClient(dio: dio);

      await client.patch('/incidentes/i-001/atender');

      expect(adapter.ultimaRequest!.method, 'PATCH');
    });
  });

  group('ApiClient — traducción DioException -> ApiException (nunca deja escapar DioException)', () {
    test('timeout del adaptador se traduce a ApiException tipo timeout', () async {
      adapter.nextError = DioException(
        requestOptions: RequestOptions(path: '/incidentes'),
        type: DioExceptionType.connectionTimeout,
      );
      final client = ApiClient(dio: dio);

      await expectLater(
        client.get('/incidentes/i-001'),
        throwsA(isA<ApiException>()
            .having((e) => e.type, 'type', ApiExceptionType.timeout)),
      );
    });

    // Regresión: DioExceptionType.transformTimeout (timeout al transformar
    // la respuesta) no estaba cubierto explícitamente en el switch de
    // ApiException.fromDioException — `flutter analyze` lo marcaba como
    // error (non_exhaustive_switch_statement) porque el enum de dio tiene
    // 9 valores, no 8. Va agrupado con los otros 3 timeouts: es el mismo
    // tipo de problema (el servidor tardó demasiado), solo que ocurre
    // durante el parseo de la respuesta en vez de la conexión/envío/
    // recepción.
    test('timeout de transformación de la respuesta también se traduce a tipo timeout',
        () async {
      adapter.nextError = DioException(
        requestOptions: RequestOptions(path: '/incidentes'),
        type: DioExceptionType.transformTimeout,
      );
      final client = ApiClient(dio: dio);

      await expectLater(
        client.get('/incidentes/i-001'),
        throwsA(isA<ApiException>()
            .having((e) => e.type, 'type', ApiExceptionType.timeout)),
      );
    });

    test('sin conexión se traduce a ApiException tipo noConnection', () async {
      adapter.nextError = DioException(
        requestOptions: RequestOptions(path: '/incidentes'),
        type: DioExceptionType.connectionError,
      );
      final client = ApiClient(dio: dio);

      await expectLater(
        client.get('/incidentes/i-001'),
        throwsA(isA<ApiException>()
            .having((e) => e.type, 'type', ApiExceptionType.noConnection)),
      );
    });

    test('respuesta 404 real (vía Dio, no simulada a mano) se traduce a ApiException notFound '
        'con el detail del ProblemDetail como mensaje', () async {
      adapter.nextStatusCode = 404;
      adapter.nextBody = {
        'title': 'Recurso no encontrado',
        'status': 404,
        'detail': 'Incidente no encontrado: i-999',
      };
      final client = ApiClient(dio: dio);

      try {
        await client.get('/incidentes/i-999');
        fail('Debió lanzar ApiException');
      } on ApiException catch (e) {
        expect(e.type, ApiExceptionType.notFound);
        expect(e.statusCode, 404);
        expect(e.message, 'Incidente no encontrado: i-999');
      }
    });

    test('respuesta 422 real se traduce a ApiException businessRule', () async {
      adapter.nextStatusCode = 422;
      adapter.nextBody = {
        'title': 'Regla de negocio violada',
        'status': 422,
        'detail': 'Transición de estado inválida',
      };
      final client = ApiClient(dio: dio);

      await expectLater(
        client.post('/incidentes/i-001/atender'),
        throwsA(isA<ApiException>()
            .having((e) => e.type, 'type', ApiExceptionType.businessRule)),
      );
    });

    test('nunca deja escapar un DioException crudo, sea cual sea el error', () async {
      adapter.nextError = DioException(
        requestOptions: RequestOptions(path: '/incidentes'),
        type: DioExceptionType.badCertificate,
      );
      final client = ApiClient(dio: dio);

      await expectLater(
        client.get('/incidentes/i-001'),
        throwsA(isNot(isA<DioException>())),
      );
    });
  });
}

class _TokenProviderMutable implements ITokenProvider {
  _TokenProviderMutable(this.token);
  @override
  String? token;
}