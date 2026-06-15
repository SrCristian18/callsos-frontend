import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:CallSos/data/services/api_client.dart';
import 'package:CallSos/data/services/api_exception.dart';
import 'package:CallSos/data/services/denunciante_service.dart';

class MockApiClient extends Mock implements IApiClient {}

void main() {
  late MockApiClient client;
  late DenuncianteService service;

  setUp(() {
    client = MockApiClient();
    service = DenuncianteService(client);
  });

  group('registrarTokenFcm', () {
    test('llama PATCH /denunciantes/{actorId}/token con {tokenFcm}', () async {
      when(() => client.patch('/denunciantes/den-123/token', data: any(named: 'data')))
          .thenAnswer((_) async => null);

      await service.registrarTokenFcm(actorId: 'den-123', tokenFcm: 'fcm-token-abc');

      verify(() => client.patch(
            '/denunciantes/den-123/token',
            data: {'tokenFcm': 'fcm-token-abc'},
          )).called(1);
    });

    test(
      'si el actorId del path no coincide con el del JWT, el backend devuelve '
      '403 -> ApiExceptionType.forbidden',
      () async {
        when(() => client.patch('/denunciantes/otro-denunciante/token', data: any(named: 'data')))
            .thenThrow(const ApiException(
          type: ApiExceptionType.forbidden,
          statusCode: 403,
          message: 'No tienes permisos para realizar esta acción.',
        ));

        await expectLater(
          service.registrarTokenFcm(actorId: 'otro-denunciante', tokenFcm: 'x'),
          throwsA(
            isA<ApiException>().having((e) => e.type, 'type', ApiExceptionType.forbidden),
          ),
        );
      },
    );
  });
}