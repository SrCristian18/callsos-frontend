import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:CallSos/data/models/enums/estado_incidente.dart';
import 'package:CallSos/data/services/api_client.dart';
import 'package:CallSos/data/services/api_exception.dart';
import 'package:CallSos/data/services/auditoria_service.dart';

class MockApiClient extends Mock implements IApiClient {}

Map<String, dynamic> _eventoJson({
  String incidenteId = 'inc-001',
  String? estadoAnterior,
  String estadoNuevo = 'CREADO',
  String actorId = 'den-001',
  String actorRol = 'DENUNCIANTE',
  String timestamp = '2026-06-14T10:00:00.000',
  String? detalle = 'Incidente creado.',
  String? campo,
  String? valorAnteriorGenerico,
  String? valorNuevoGenerico,
}) {
  return {
    'incidenteId': incidenteId,
    'estadoAnterior': estadoAnterior,
    'estadoNuevo': estadoNuevo,
    'actorId': actorId,
    'actorRol': actorRol,
    'timestamp': timestamp,
    'detalle': detalle,
    'campo': campo,
    'valorAnteriorGenerico': valorAnteriorGenerico,
    'valorNuevoGenerico': valorNuevoGenerico,
  };
}

void main() {
  late MockApiClient client;
  late AuditoriaService service;

  setUp(() {
    client = MockApiClient();
    service = AuditoriaService(client);
  });

  group('historial', () {
    test('GET /auditoria/incidente/{id} y mapea la lista completa, '
        'en el mismo orden en que llega (cronológico, ya ordenado por el '
        'backend)', () async {
      when(() => client.get('/auditoria/incidente/inc-001')).thenAnswer(
        (_) async => [
          _eventoJson(estadoNuevo: 'CREADO', detalle: 'Incidente creado.'),
          _eventoJson(
            estadoAnterior: 'CREADO',
            estadoNuevo: 'DERIVADO_A_CAI',
            actorId: 'com-001',
            actorRol: 'COMANDO',
            timestamp: '2026-06-14T10:05:00.000',
            detalle: 'Derivado al CAI más cercano.',
          ),
        ],
      );

      final historial = await service.historial('inc-001');

      expect(historial, hasLength(2));
      expect(historial[0].estadoNuevo, EstadoIncidente.CREADO);
      expect(historial[0].estadoAnterior, isNull);
      expect(historial[1].estadoAnterior, EstadoIncidente.CREADO);
      expect(historial[1].estadoNuevo, EstadoIncidente.DERIVADO_A_CAI);
      expect(historial[1].actorRol, 'COMANDO');

      verify(() => client.get('/auditoria/incidente/inc-001')).called(1);
    });

    test('lista vacía (incidente sin eventos todavía) se mapea a []', () async {
      when(() => client.get('/auditoria/incidente/inc-002'))
          .thenAnswer((_) async => <dynamic>[]);

      final historial = await service.historial('inc-002');

      expect(historial, isEmpty);
    });

    test('mapea un cambio de campo genérico (ej. actualización de tipo)', () async {
      when(() => client.get('/auditoria/incidente/inc-003')).thenAnswer(
        (_) async => [
          _eventoJson(
            estadoNuevo: 'DERIVADO_A_CAI',
            campo: 'tipo',
            valorAnteriorGenerico: 'ROBOS_O_ASALTOS',
            valorNuevoGenerico: 'RIÑAS_O_PELEAS',
            detalle: 'El denunciante actualizó el tipo de incidente.',
          ),
        ],
      );

      final historial = await service.historial('inc-003');

      expect(historial.single.esCambioGenerico, isTrue);
      expect(historial.single.campo, 'tipo');
      expect(historial.single.valorNuevoGenerico, 'RIÑAS_O_PELEAS');
    });

    test('propaga ApiException tal cual (ej. 403 — actor sin autorización '
        'sobre este incidente, filtrado del lado del backend)', () async {
      when(() => client.get('/auditoria/incidente/inc-ajeno')).thenThrow(
        const ApiException(
          type: ApiExceptionType.forbidden,
          message: 'No tiene autorización para consultar la auditoría de este incidente.',
        ),
      );

      expect(
        () => service.historial('inc-ajeno'),
        throwsA(isA<ApiException>().having(
            (e) => e.type, 'type', ApiExceptionType.forbidden)),
      );
    });
  });
}