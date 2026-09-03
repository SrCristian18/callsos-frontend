import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:CallSos/data/services/api_client.dart';
import 'package:CallSos/data/services/api_exception.dart';
import 'package:CallSos/data/services/cai_service.dart';

class MockApiClient extends Mock implements IApiClient {}

void main() {
  late MockApiClient client;
  late CaiService service;

  setUp(() {
    client = MockApiClient();
    service = CaiService(client);
  });

  group('agentesDisponibles', () {
    test('GET /cais/{caiId}/agentes/disponibles devuelve la lista mapeada',
        () async {
      when(() => client.get('/cais/cai-001/agentes/disponibles'))
          .thenAnswer((_) async => [
                {
                  'id': 'ag-001',
                  'nombre': 'Pedro Agente',
                  'telefono': '3001111111',
                  'estado': 'DISPONIBLE',
                },
              ]);

      final agentes = await service.agentesDisponibles('cai-001');

      expect(agentes, hasLength(1));
      expect(agentes.first.id, 'ag-001');
      expect(agentes.first.nombre, 'Pedro Agente');
    });

    test(
      'CAI ajeno (Épica 8, hallazgo #3) -> el backend devuelve 403 -> '
      'ApiExceptionType.forbidden',
      () async {
        when(() => client.get('/cais/cai-002/agentes/disponibles'))
            .thenThrow(const ApiException(
          type: ApiExceptionType.forbidden,
          statusCode: 403,
          message: 'El operador autenticado no pertenece a este CAI.',
        ));

        await expectLater(
          service.agentesDisponibles('cai-002'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.type, 'type', ApiExceptionType.forbidden),
          ),
        );
      },
    );
  });

  group('generarInvitacion', () {
    test('POST /invitaciones con unidadPolicialId devuelve la invitación',
        () async {
      when(() => client.post('/invitaciones', data: any(named: 'data')))
          .thenAnswer((_) async => {
                'token': 'tok-abc123',
                'unidadPolicialId': 'cai-001',
                'fechaExpiracion': '2026-06-20T10:00:00',
              });

      final invitacion = await service.generarInvitacion('cai-001');

      expect(invitacion.token, 'tok-abc123');
      expect(invitacion.unidadPolicialId, 'cai-001');
      verify(() => client.post(
            '/invitaciones',
            data: {'unidadPolicialId': 'cai-001'},
          )).called(1);
    });
  });

  group('registrarTokenFcm (Épica 8, hallazgo #5)', () {
    test('llama PATCH /cais/{unidadPolicialId}/token con {tokenFcm}',
        () async {
      when(() => client.patch('/cais/cai-001/token', data: any(named: 'data')))
          .thenAnswer((_) async => null);

      await service.registrarTokenFcm(
          unidadPolicialId: 'cai-001', tokenFcm: 'fcm-token-abc');

      verify(() => client.patch(
            '/cais/cai-001/token',
            data: {'tokenFcm': 'fcm-token-abc'},
          )).called(1);
    });

    test(
      'CAI ajeno -> el backend devuelve 403 -> ApiExceptionType.forbidden',
      () async {
        when(() => client.patch('/cais/cai-002/token', data: any(named: 'data')))
            .thenThrow(const ApiException(
          type: ApiExceptionType.forbidden,
          statusCode: 403,
          message: 'No tienes permisos para realizar esta acción.',
        ));

        await expectLater(
          service.registrarTokenFcm(
              unidadPolicialId: 'cai-002', tokenFcm: 'x'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.type, 'type', ApiExceptionType.forbidden),
          ),
        );
      },
    );
  });
}