import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:CallSos/data/services/api_exception.dart';
import 'package:CallSos/data/services/reporte_service.dart';
import 'package:CallSos/presentation/viewmodels/reporte_hallazgos_viewmodel.dart';

class MockReporteService extends Mock implements IReporteService {}

ReporteHallazgosResult _fakeResultado() => ReporteHallazgosResult(
      id: 'rep-001',
      fecha: DateTime(2026, 6, 14, 12, 0),
      incidenteId: 'inc-001',
      agenteId: 'agente-001',
    );

void main() {
  late MockReporteService service;
  late ReporteHallazgosViewModel vm;

  setUp(() {
    service = MockReporteService();
    vm = ReporteHallazgosViewModel(reporteService: service);
  });

  tearDown(() => vm.dispose());

  group('estado inicial', () {
    test('inicia en idle sin error ni descripción', () {
      expect(vm.estado, ReporteHallazgosEstado.idle);
      expect(vm.descripcion, isEmpty);
      expect(vm.formularioValido, isFalse);
      expect(vm.isLoading, isFalse);
      expect(vm.errorMessage, isNull);
    });

    test('formularioValido solo cuando descripción no está vacía', () {
      expect(vm.formularioValido, isFalse);
      vm.descripcion = 'Algo';
      expect(vm.formularioValido, isTrue);
      vm.descripcion = '   ';   // solo espacios — no válido
      expect(vm.formularioValido, isFalse);
    });
  });

  group('enviar — éxito', () {
    test('llamada exitosa → estado exito, devuelve true', () async {
      when(() => service.crearHallazgos(
            incidenteId: any(named: 'incidenteId'),
            agenteId: any(named: 'agenteId'),
            descripcion: any(named: 'descripcion'),
          )).thenAnswer((_) async => _fakeResultado());

      vm.descripcion = 'Se atendió el incidente sin novedades.';
      final ok =
          await vm.enviar(incidenteId: 'inc-001', agenteId: 'agente-001');

      expect(ok, isTrue);
      expect(vm.estado, ReporteHallazgosEstado.exito);
      expect(vm.errorMessage, isNull);
    });

    test('envía la descripción recortada (trim)', () async {
      when(() => service.crearHallazgos(
            incidenteId: any(named: 'incidenteId'),
            agenteId: any(named: 'agenteId'),
            descripcion: any(named: 'descripcion'),
          )).thenAnswer((_) async => _fakeResultado());

      vm.descripcion = '  descripción con espacios  ';
      await vm.enviar(incidenteId: 'inc-001', agenteId: 'agente-001');

      final captured = verify(() => service.crearHallazgos(
            incidenteId: any(named: 'incidenteId'),
            agenteId: any(named: 'agenteId'),
            descripcion: captureAny(named: 'descripcion'),
          )).captured.single as String;

      expect(captured, 'descripción con espacios');
    });

    test('descripción vacía → false sin llamar al servicio', () async {
      final ok =
          await vm.enviar(incidenteId: 'inc-001', agenteId: 'agente-001');

      expect(ok, isFalse);
      verifyNever(() => service.crearHallazgos(
            incidenteId: any(named: 'incidenteId'),
            agenteId: any(named: 'agenteId'),
            descripcion: any(named: 'descripcion'),
          ));
    });
  });

  group('enviar — errores', () {
    test(
        '422 businessRule (incidente no EN_ATENCION) → estado error + mensaje backend',
        () async {
      when(() => service.crearHallazgos(
            incidenteId: any(named: 'incidenteId'),
            agenteId: any(named: 'agenteId'),
            descripcion: any(named: 'descripcion'),
          )).thenAnswer((_) => Future.error(const ApiException(
            type: ApiExceptionType.businessRule,
            statusCode: 422,
            message:
                'Solo se puede reportar sobre un incidente EN_ATENCION.',
          )));

      vm.descripcion = 'Descripción de prueba';
      final ok =
          await vm.enviar(incidenteId: 'inc-001', agenteId: 'agente-001');

      expect(ok, isFalse);
      expect(vm.estado, ReporteHallazgosEstado.error);
      expect(vm.errorMessage, contains('EN_ATENCION'));
    });

    test('sin conexión → estado error con mensaje de red', () async {
      when(() => service.crearHallazgos(
            incidenteId: any(named: 'incidenteId'),
            agenteId: any(named: 'agenteId'),
            descripcion: any(named: 'descripcion'),
          )).thenAnswer((_) => Future.error(const ApiException(
            type: ApiExceptionType.noConnection,
            message: 'No se pudo conectar con el servidor.',
          )));

      vm.descripcion = 'Descripción de prueba';
      final ok =
          await vm.enviar(incidenteId: 'inc-001', agenteId: 'agente-001');

      expect(ok, isFalse);
      expect(vm.estado, ReporteHallazgosEstado.error);
      expect(vm.errorMessage, contains('servidor'));
    });
  });

  group('resetear', () {
    test('vuelve al estado idle limpiando todos los campos', () async {
      when(() => service.crearHallazgos(
            incidenteId: any(named: 'incidenteId'),
            agenteId: any(named: 'agenteId'),
            descripcion: any(named: 'descripcion'),
          )).thenAnswer((_) async => _fakeResultado());

      vm.descripcion = 'texto';
      await vm.enviar(incidenteId: 'inc-001', agenteId: 'agente-001');
      expect(vm.estado, ReporteHallazgosEstado.exito);

      vm.resetear();

      expect(vm.estado, ReporteHallazgosEstado.idle);
      expect(vm.descripcion, isEmpty);
      expect(vm.errorMessage, isNull);
      expect(vm.formularioValido, isFalse);
    });
  });
}