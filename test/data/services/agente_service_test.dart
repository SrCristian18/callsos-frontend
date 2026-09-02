import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:CallSos/data/services/agente_service.dart';
import 'package:CallSos/data/services/api_client.dart';
import 'package:CallSos/data/services/api_exception.dart';

class MockApiClient extends Mock implements IApiClient {}

void main() {
  late MockApiClient client;
  late AgenteService service;

  setUp(() {
    client = MockApiClient();
    service = AgenteService(client);
  });

  group('registrarTokenFcm (Épica 8, hallazgo #5)', () {
    test('llama PATCH /agentes/{actorId}/token con {tokenFcm}', () async {
      when(() => client.patch('/agentes/ag-123/token', data: any(named: 'data')))
          .thenAnswer((_) async => null);

      await service.registrarTokenFcm(actorId: 'ag-123', tokenFcm: 'fcm-token-abc');

      verify(() => client.patch(
            '/agentes/ag-123/token',
            data: {'tokenFcm': 'fcm-token-abc'},
          )).called(1);
    });

    test(
      'si el actorId del path no coincide con el del JWT, el backend devuelve '
      '403 -> ApiExceptionType.forbidden',
      () async {
        when(() => client.patch('/agentes/otro-agente/token', data: any(named: 'data')))
            .thenThrow(const ApiException(
          type: ApiExceptionType.forbidden,
          statusCode: 403,
          message: 'No tienes permisos para realizar esta acción.',
        ));

        await expectLater(
          service.registrarTokenFcm(actorId: 'otro-agente', tokenFcm: 'x'),
          throwsA(
            isA<ApiException>().having((e) => e.type, 'type', ApiExceptionType.forbidden),
          ),
        );
      },
    );
  });
}