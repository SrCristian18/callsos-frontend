import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:CallSos/data/services/api_client.dart';
import 'package:CallSos/data/services/reporte_service.dart';

class MockApiClient extends Mock implements IApiClient {}

void main() {
  late MockApiClient client;
  late ReporteService service;

  setUp(() {
    client = MockApiClient();
    service = ReporteService(client);
  });

  group('crearHallazgos', () {
    test('envía el body sin agenteId (Épica 8: lo determina el backend vía JWT) '
        'y mapea ReporteHallazgosResponse, que SÍ trae agenteId (informativo)', () async {
      when(() => client.post('/reportes/hallazgos', data: any(named: 'data')))
          .thenAnswer((_) async => {
                'id': 'rep-001',
                'fecha': '2026-06-14T12:00:00',
                'incidenteId': 'inc-001',
                'agenteId': 'agente-001',
              });

      final resultado = await service.crearHallazgos(
        incidenteId: 'inc-001',
        descripcion: 'Se atendió la riña, ambas partes calmadas.',
      );

      expect(resultado.id, 'rep-001');
      expect(resultado.incidenteId, 'inc-001');
      expect(resultado.agenteId, 'agente-001');
      expect(resultado.fecha, DateTime.parse('2026-06-14T12:00:00'));

      // El body NO lleva agenteId — ya no hay forma de que el cliente
      // declare de quién es el reporte, el backend lo saca del JWT.
      verify(() => client.post('/reportes/hallazgos', data: {
            'incidenteId': 'inc-001',
            'descripcion': 'Se atendió la riña, ambas partes calmadas.',
          })).called(1);
    });
  });

  group('crearAdministrativo', () {
    test('envía el body correcto y mapea ReporteAdministrativoResponse', () async {
      when(() => client.post('/reportes/administrativo', data: any(named: 'data')))
          .thenAnswer((_) async => {
                'id': 'rep-adm-001',
                'fecha': '2026-06-14T13:00:00',
                'incidenteId': 'inc-001',
                'autoridadId': 'cai-007',
              });

      final resultado = await service.crearAdministrativo(
        incidenteId: 'inc-001',
        autoridadId: 'cai-007',
        resumen: 'Incidente atendido sin novedades.',
      );

      expect(resultado.id, 'rep-adm-001');
      expect(resultado.incidenteId, 'inc-001');
      expect(resultado.autoridadId, 'cai-007');

      verify(() => client.post('/reportes/administrativo', data: {
            'incidenteId': 'inc-001',
            'autoridadId': 'cai-007',
            'resumen': 'Incidente atendido sin novedades.',
          })).called(1);
    });
  });
}