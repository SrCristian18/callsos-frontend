import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:CallSos/data/models/enums/estado_incidente.dart';
import 'package:CallSos/data/models/enums/tipo_incidente_enum.dart';
import 'package:CallSos/data/models/valueobject/ubicacion.dart';
import 'package:CallSos/data/services/api_client.dart';
import 'package:CallSos/data/services/api_exception.dart';
import 'package:CallSos/data/services/incidente_service.dart';

class MockApiClient extends Mock implements IApiClient {}

Map<String, dynamic> _incidenteJson({
  String id = 'inc-001',
  String estado = 'CREADO',
  String? unidadPolicialId,
  String? nombreCAI,
}) {
  return {
    'id': id,
    'fechaHora': '2026-06-14T10:30:00.000',
    'tipo': 'ROBOS_O_ASALTOS',
    'descripcion': 'Robo a mano armada.',
    'estado': estado,
    'latitud': 10.391,
    'longitud': -75.4794,
    'denuncianteId': 'den-123',
    'unidadPolicialId': unidadPolicialId,
    'nombreCAI': nombreCAI,
  };
}

void main() {
  late MockApiClient client;
  late IncidenteService service;

  setUp(() {
    client = MockApiClient();
    service = IncidenteService(client);
  });

  group('crear', () {
    test('envía el body correcto (espejo de CrearIncidenteRequest) y mapea la respuesta', () async {
      when(() => client.post('/incidentes', data: any(named: 'data')))
          .thenAnswer((_) async => _incidenteJson());

      final ubicacion = Ubicacion(latitud: 10.391, longitud: -75.4794);
      final incidente = await service.crear(
        denuncianteId: 'den-123',
        tipo: TipoIncidenteEnum.ROBOS_O_ASALTOS,
        descripcion: 'Robo a mano armada.',
        ubicacion: ubicacion,
      );

      expect(incidente.id, 'inc-001');
      expect(incidente.estado, EstadoIncidente.CREADO);
      expect(incidente.tipo, TipoIncidenteEnum.ROBOS_O_ASALTOS);

      verify(() => client.post('/incidentes', data: {
            'denuncianteId': 'den-123',
            'tipo': 'ROBOS_O_ASALTOS',
            'descripcion': 'Robo a mano armada.',
            'ubicacion': {'latitud': 10.391, 'longitud': -75.4794},
          })).called(1);
    });

    test('crear con tipo RIÑAS_O_PELEAS envía el string correcto con Ñ', () async {
      when(() => client.post('/incidentes', data: any(named: 'data')))
          .thenAnswer((_) async => _incidenteJson());

      await service.crear(
        denuncianteId: 'den-123',
        tipo: TipoIncidenteEnum.RINAS_O_PELEAS,
        descripcion: 'Riña en la calle.',
        ubicacion: Ubicacion(latitud: 0, longitud: 0),
      );

      final captured = verify(() => client.post('/incidentes', data: captureAny(named: 'data')))
          .captured
          .single as Map<String, dynamic>;

      expect(captured['tipo'], 'RIÑAS_O_PELEAS');
    });
  });

  group('consultar / consultarEstado', () {
    test('consultar mapea GET /incidentes/{id} a Incidente', () async {
      when(() => client.get('/incidentes/inc-001'))
          .thenAnswer((_) async => _incidenteJson(estado: 'AGENTE_EN_CAMINO'));

      final incidente = await service.consultar('inc-001');

      expect(incidente.id, 'inc-001');
      expect(incidente.estado, EstadoIncidente.AGENTE_EN_CAMINO);
    });

    test('consultarEstado mapea el string JSON plano devuelto por el backend', () async {
      // GET /incidentes/{id}/estado devuelve "AGENTE_EN_CAMINO" (string JSON
      // plano, no un objeto), tal como Spring serializa un enum directo.
      when(() => client.get('/incidentes/inc-001/estado'))
          .thenAnswer((_) async => 'AGENTE_EN_CAMINO');

      final estado = await service.consultarEstado('inc-001');

      expect(estado, EstadoIncidente.AGENTE_EN_CAMINO);
    });
  });

  group('listas', () {
    test('misIncidentes mapea la lista devuelta por GET /incidentes/mis-incidentes', () async {
      when(() => client.get('/incidentes/mis-incidentes')).thenAnswer((_) async => [
            _incidenteJson(id: 'inc-001', estado: 'CREADO'),
            _incidenteJson(id: 'inc-002', estado: 'FINALIZADO'),
          ]);

      final incidentes = await service.misIncidentes();

      expect(incidentes, hasLength(2));
      expect(incidentes[0].id, 'inc-001');
      expect(incidentes[1].estado, EstadoIncidente.FINALIZADO);
    });

    test('asignados mapea GET /incidentes/asignados', () async {
      when(() => client.get('/incidentes/asignados'))
          .thenAnswer((_) async => [_incidenteJson(id: 'inc-003', estado: 'AGENTE_ASIGNADO')]);

      final incidentes = await service.asignados();

      expect(incidentes, hasLength(1));
      expect(incidentes.single.id, 'inc-003');
    });

    test('porCai mapea GET /incidentes/por-cai', () async {
      when(() => client.get('/incidentes/por-cai')).thenAnswer((_) async => [
            _incidenteJson(
              id: 'inc-004',
              estado: 'DERIVADO_A_CAI',
              unidadPolicialId: 'cai-007',
              nombreCAI: 'CAI San Francisco',
            ),
          ]);

      final incidentes = await service.porCai();

      expect(incidentes.single.nombreCAI, 'CAI San Francisco');
    });

    test('lista vacía no falla', () async {
      when(() => client.get('/incidentes/mis-incidentes')).thenAnswer((_) async => <dynamic>[]);

      final incidentes = await service.misIncidentes();

      expect(incidentes, isEmpty);
    });
  });

  group('transiciones de estado (PATCH, 204 No Content)', () {
    test('derivar llama PATCH /incidentes/{id}/derivar sin body', () async {
      when(() => client.patch('/incidentes/inc-001/derivar')).thenAnswer((_) async => null);

      await service.derivar('inc-001');

      verify(() => client.patch('/incidentes/inc-001/derivar')).called(1);
    });

    test('asignar llama PATCH /incidentes/{id}/asignar sin body', () async {
      when(() => client.patch('/incidentes/inc-001/asignar')).thenAnswer((_) async => null);

      await service.asignar('inc-001');

      verify(() => client.patch('/incidentes/inc-001/asignar')).called(1);
    });

    test('enCamino llama PATCH /incidentes/{id}/en-camino', () async {
      when(() => client.patch('/incidentes/inc-001/en-camino')).thenAnswer((_) async => null);

      await service.enCamino('inc-001');

      verify(() => client.patch('/incidentes/inc-001/en-camino')).called(1);
    });

    test('atender llama PATCH /incidentes/{id}/atender', () async {
      when(() => client.patch('/incidentes/inc-001/atender')).thenAnswer((_) async => null);

      await service.atender('inc-001');

      verify(() => client.patch('/incidentes/inc-001/atender')).called(1);
    });

    test('evaluar llama PATCH /incidentes/{id}/evaluar', () async {
      when(() => client.patch('/incidentes/inc-001/evaluar')).thenAnswer((_) async => null);

      await service.evaluar('inc-001');

      verify(() => client.patch('/incidentes/inc-001/evaluar')).called(1);
    });

    test('cancelar llama PATCH /incidentes/{id}/cancelar', () async {
      when(() => client.patch('/incidentes/inc-001/cancelar')).thenAnswer((_) async => null);

      await service.cancelar('inc-001');

      verify(() => client.patch('/incidentes/inc-001/cancelar')).called(1);
    });

    test('cambiarEstado envía {"nuevoEstado": ...} (espejo de CambiarEstadoRequest)', () async {
      when(() => client.patch('/incidentes/inc-001/estado', data: any(named: 'data')))
          .thenAnswer((_) async => null);

      await service.cambiarEstado('inc-001', EstadoIncidente.CANCELADO);

      verify(() => client.patch('/incidentes/inc-001/estado', data: {'nuevoEstado': 'CANCELADO'}))
          .called(1);
    });

    test('una transición inválida propaga ApiException 422 businessRule', () async {
      when(() => client.patch('/incidentes/inc-001/atender')).thenThrow(const ApiException(
        type: ApiExceptionType.businessRule,
        statusCode: 422,
        message: 'No se puede atender un incidente sin agente asignado',
      ));

      await expectLater(
        service.atender('inc-001'),
        throwsA(
          isA<ApiException>().having((e) => e.type, 'type', ApiExceptionType.businessRule),
        ),
      );
    });
  });
}