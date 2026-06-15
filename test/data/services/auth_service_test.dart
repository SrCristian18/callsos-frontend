import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:CallSos/data/models/enums/rol.dart';
import 'package:CallSos/data/services/api_client.dart';
import 'package:CallSos/data/services/api_exception.dart';
import 'package:CallSos/data/services/auth_service.dart';

class MockApiClient extends Mock implements IApiClient {}

void main() {
  late MockApiClient client;
  late AuthService service;

  setUp(() {
    client = MockApiClient();
    service = AuthService(client);
  });

  group('AuthService.login', () {
    test('login exitoso devuelve AuthResult mapeado desde AuthResponse', () async {
      when(() => client.post('/auth/login', data: any(named: 'data')))
          .thenAnswer((_) async => {
                'token': 'eyJ.fake.token',
                'actorId': 'agente-001',
                'rol': 'AGENTE',
              });

      final result = await service.login(
        username: 'pedro.agente',
        password: 'password123',
      );

      expect(result.token, 'eyJ.fake.token');
      expect(result.actorId, 'agente-001');
      expect(result.rol, Rol.AGENTE);

      verify(() => client.post(
            '/auth/login',
            data: {'username': 'pedro.agente', 'password': 'password123'},
          )).called(1);
    });

    test(
      '404 del backend (credenciales inválidas) se traduce a ApiExceptionType.unauthorized',
      () async {
        when(() => client.post('/auth/login', data: any(named: 'data')))
            .thenThrow(const ApiException(
          type: ApiExceptionType.notFound,
          statusCode: 404,
          message: 'Usuario o contraseña incorrectos',
        ));

        await expectLater(
          service.login(username: 'x', password: 'y'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.type, 'type', ApiExceptionType.unauthorized),
          ),
        );
      },
    );

    test('errores de servidor (500) se propagan sin modificar', () async {
      when(() => client.post('/auth/login', data: any(named: 'data')))
          .thenThrow(const ApiException(
        type: ApiExceptionType.server,
        statusCode: 500,
        message: 'Error interno',
      ));

      await expectLater(
        service.login(username: 'x', password: 'y'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.type, 'type', ApiExceptionType.server),
        ),
      );
    });

    test('sin conexión (backend no responde) se propaga sin modificar', () async {
      when(() => client.post('/auth/login', data: any(named: 'data')))
          .thenThrow(const ApiException(
        type: ApiExceptionType.noConnection,
        message: 'No se pudo conectar con el servidor.',
      ));

      await expectLater(
        service.login(username: 'x', password: 'y'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.type, 'type', ApiExceptionType.noConnection),
        ),
      );
    });
  });
}