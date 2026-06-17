import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:CallSos/data/models/enums/estado_incidente.dart';
import 'package:CallSos/data/models/enums/tipo_incidente_enum.dart';
import 'package:CallSos/data/models/incidente.dart';
import 'package:CallSos/data/services/api_exception.dart';
import 'package:CallSos/data/services/incidente_service.dart';
import 'package:CallSos/presentation/viewmodels/incidente_list_viewmodel.dart';

class MockIncidenteService extends Mock implements IIncidenteService {}

Incidente _fake(String id, EstadoIncidente estado) => Incidente(
      id: id,
      fechaHora: DateTime(2026, 6, 14),
      tipo: TipoIncidenteEnum.ROBOS_O_ASALTOS,
      descripcion: 'desc',
      estado: estado,
      latitud: 10.391,
      longitud: -75.4794,
      denuncianteId: 'den-001',
    );

void main() {
  late MockIncidenteService service;
  late IncidenteListViewModel vm;

  setUp(() {
    service = MockIncidenteService();
    vm = IncidenteListViewModel(
      service: service,
      fetchFn: service.misIncidentes,
    );
  });

  tearDown(() => vm.dispose());

  group('cargar', () {
    test('carga exitosa: lista poblada, isLoading false, sin error', () async {
      when(() => service.misIncidentes()).thenAnswer((_) async => [
            _fake('inc-001', EstadoIncidente.CREADO),
            _fake('inc-002', EstadoIncidente.FINALIZADO),
          ]);

      await vm.cargar();

      expect(vm.incidentes, hasLength(2));
      expect(vm.isLoading, isFalse);
      expect(vm.errorMessage, isNull);
    });

    test('error en carga: errorMessage seteado, lista vacía', () async {
      when(() => service.misIncidentes()).thenAnswer(
        (_) => Future.error(const ApiException(
          type: ApiExceptionType.noConnection,
          message: 'Sin conexión',
        )),
      );

      await vm.cargar();

      expect(vm.incidentes, isEmpty);
      expect(vm.errorMessage, 'Sin conexión');
      expect(vm.isLoading, isFalse);
    });

    test('lista vacía sin error', () async {
      when(() => service.misIncidentes())
          .thenAnswer((_) async => <Incidente>[]);

      await vm.cargar();

      expect(vm.incidentes, isEmpty);
      expect(vm.errorMessage, isNull);
    });
  });

  group('incidentesPorEstado', () {
    setUp(() async {
      when(() => service.misIncidentes()).thenAnswer((_) async => [
            _fake('inc-001', EstadoIncidente.CREADO),
            _fake('inc-002', EstadoIncidente.DERIVADO_A_CAI),
            _fake('inc-003', EstadoIncidente.FINALIZADO),
            _fake('inc-004', EstadoIncidente.CANCELADO),
          ]);
      await vm.cargar();
    });

    test('filtra por estado único', () {
      final creados =
          vm.incidentesPorEstado([EstadoIncidente.CREADO]);
      expect(creados, hasLength(1));
      expect(creados.first.id, 'inc-001');
    });

    test('filtra por múltiples estados', () {
      final terminados = vm.incidentesPorEstado([
        EstadoIncidente.FINALIZADO,
        EstadoIncidente.CANCELADO,
      ]);
      expect(terminados, hasLength(2));
    });

    test('estado no presente devuelve lista vacía', () {
      final result = vm.incidentesPorEstado(
          [EstadoIncidente.EN_ATENCION]);
      expect(result, isEmpty);
    });
  });

  group('ejecutarTransicion', () {
    test('transición exitosa refresca la lista y devuelve true', () async {
      // Carga inicial
      when(() => service.misIncidentes())
          .thenAnswer((_) async => [_fake('inc-001', EstadoIncidente.CREADO)]);
      await vm.cargar();
      expect(vm.incidentes.first.estado, EstadoIncidente.CREADO);

      // Después de la transición, la lista se actualiza
      when(() => service.misIncidentes()).thenAnswer((_) async =>
          [_fake('inc-001', EstadoIncidente.DERIVADO_A_CAI)]);

      final ok = await vm.ejecutarTransicion(
        incidenteId: 'inc-001',
        accion: () async {},
      );

      expect(ok, isTrue);
      expect(vm.incidentes.first.estado, EstadoIncidente.DERIVADO_A_CAI);
      expect(vm.idEnProceso, isNull);
      expect(vm.errorMessage, isNull);
    });

    test('transición fallida (422 businessRule) → errorMessage, devuelve false',
        () async {
      when(() => service.misIncidentes())
          .thenAnswer((_) async => [_fake('inc-001', EstadoIncidente.CREADO)]);
      await vm.cargar();

      final ok = await vm.ejecutarTransicion(
        incidenteId: 'inc-001',
        accion: () => Future.error(const ApiException(
          type: ApiExceptionType.businessRule,
          statusCode: 422,
          message: 'Transición inválida en el estado actual',
        )),
      );

      expect(ok, isFalse);
      expect(vm.errorMessage, 'Transición inválida en el estado actual');
      expect(vm.idEnProceso, isNull);
    });

    test('enProceso(id) es true durante la transición', () async {
      when(() => service.misIncidentes())
          .thenAnswer((_) async => [_fake('inc-001', EstadoIncidente.CREADO)]);
      await vm.cargar();

      bool? enProcesoMidTransaction;

      final future = vm.ejecutarTransicion(
        incidenteId: 'inc-001',
        accion: () async {
          enProcesoMidTransaction = vm.enProceso('inc-001');
        },
      );

      await future;

      expect(enProcesoMidTransaction, isTrue);
      expect(vm.enProceso('inc-001'), isFalse); // limpio al terminar
    });
  });
}