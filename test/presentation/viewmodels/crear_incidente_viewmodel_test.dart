import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:CallSos/data/models/enums/estado_incidente.dart';
import 'package:CallSos/data/models/enums/tipo_incidente_enum.dart';
import 'package:CallSos/data/models/incidente.dart';
import 'package:CallSos/data/models/valueobject/ubicacion.dart';
import 'package:CallSos/data/services/api_exception.dart';
import 'package:CallSos/data/services/geolocalizacion_service.dart';
import 'package:CallSos/data/services/incidente_service.dart';
import 'package:CallSos/presentation/viewmodels/crear_incidente_viewmodel.dart';

class MockIncidenteService extends Mock implements IIncidenteService {}
class MockGeoService extends Mock implements IGeolocalizacionService {}

// Registerfall para mocktail — Ubicacion no tiene constructor const.
class FakeUbicacion extends Fake implements Ubicacion {}

Incidente _incidenteFake() => Incidente(
      id: 'inc-001',
      fechaHora: DateTime(2026, 6, 14, 10, 0),
      tipo: TipoIncidenteEnum.ROBOS_O_ASALTOS,
      descripcion: 'Robo a mano armada.',
      estado: EstadoIncidente.CREADO,
      latitud: 10.391,
      longitud: -75.4794,
      denuncianteId: 'den-001',
    );

void main() {
  late MockIncidenteService incidenteService;
  late MockGeoService geoService;
  late CrearIncidenteViewModel vm;

  setUpAll(() {
    registerFallbackValue(FakeUbicacion());
    registerFallbackValue(TipoIncidenteEnum.ROBOS_O_ASALTOS);
  });

  setUp(() {
    incidenteService = MockIncidenteService();
    geoService = MockGeoService();
    vm = CrearIncidenteViewModel(
      incidenteService: incidenteService,
      geoService: geoService,
    );
  });

  group('Estado inicial', () {
    test('inicia en idle, sin tipo seleccionado ni error', () {
      expect(vm.estado, CrearIncidenteEstado.idle);
      expect(vm.tipoSeleccionado, isNull);
      expect(vm.formularioValido, isFalse);
      expect(vm.isLoading, isFalse);
      expect(vm.errorMessage, isNull);
      expect(vm.incidenteCreado, isNull);
    });

    test('formularioValido solo cuando hay tipo seleccionado', () {
      expect(vm.formularioValido, isFalse);
      vm.seleccionarTipo(TipoIncidenteEnum.ROBOS_O_ASALTOS);
      expect(vm.formularioValido, isTrue);
    });
  });

  group('crearIncidente — flujo exitoso', () {
    test('GPS concedido + backend OK → estado exito + incidenteCreado', () async {
      when(() => geoService.solicitarPermiso())
          .thenAnswer((_) async => PermisoGpsResultado.concedido);
      when(() => geoService.obtenerPosicionActual())
          .thenAnswer((_) async => Ubicacion(latitud: 10.391, longitud: -75.4794));
      when(() => incidenteService.crear(
            denuncianteId: any(named: 'denuncianteId'),
            tipo: any(named: 'tipo'),
            descripcion: any(named: 'descripcion'),
            ubicacion: any(named: 'ubicacion'),
          )).thenAnswer((_) async => _incidenteFake());

      vm.seleccionarTipo(TipoIncidenteEnum.ROBOS_O_ASALTOS);
      vm.descripcion = 'Robo en la calle';

      final resultado = await vm.crearIncidente(denuncianteId: 'den-001');

      expect(resultado, isTrue);
      expect(vm.estado, CrearIncidenteEstado.exito);
      expect(vm.incidenteCreado, isNotNull);
      expect(vm.incidenteCreado!.id, 'inc-001');
      expect(vm.errorMessage, isNull);
    });

    test('envía la descripción recortada (trim) al servicio', () async {
      when(() => geoService.solicitarPermiso())
          .thenAnswer((_) async => PermisoGpsResultado.concedido);
      when(() => geoService.obtenerPosicionActual())
          .thenAnswer((_) async => Ubicacion(latitud: 0, longitud: 0));
      when(() => incidenteService.crear(
            denuncianteId: any(named: 'denuncianteId'),
            tipo: any(named: 'tipo'),
            descripcion: any(named: 'descripcion'),
            ubicacion: any(named: 'ubicacion'),
          )).thenAnswer((_) async => _incidenteFake());

      vm.seleccionarTipo(TipoIncidenteEnum.ROBOS_O_ASALTOS);
      vm.descripcion = '  descripción con espacios  ';
      await vm.crearIncidente(denuncianteId: 'den-001');

      final captured = verify(() => incidenteService.crear(
            denuncianteId: any(named: 'denuncianteId'),
            tipo: any(named: 'tipo'),
            descripcion: captureAny(named: 'descripcion'),
            ubicacion: any(named: 'ubicacion'),
          )).captured;

      expect(captured.single, 'descripción con espacios');
    });
  });

  group('crearIncidente — errores de GPS', () {
    test('permiso denegado → estado error con mensaje apropiado', () async {
      when(() => geoService.solicitarPermiso())
          .thenAnswer((_) async => PermisoGpsResultado.denegado);

      vm.seleccionarTipo(TipoIncidenteEnum.ROBOS_O_ASALTOS);
      final resultado = await vm.crearIncidente(denuncianteId: 'den-001');

      expect(resultado, isFalse);
      expect(vm.estado, CrearIncidenteEstado.error);
      expect(vm.errorMessage, contains('permiso'));
      verifyNever(() => incidenteService.crear(
            denuncianteId: any(named: 'denuncianteId'),
            tipo: any(named: 'tipo'),
            descripcion: any(named: 'descripcion'),
            ubicacion: any(named: 'ubicacion'),
          ));
    });

    test('servicio GPS desactivado → error con mensaje de ajustes', () async {
      when(() => geoService.solicitarPermiso())
          .thenAnswer((_) async => PermisoGpsResultado.servicioDesactivado);

      vm.seleccionarTipo(TipoIncidenteEnum.RUIDO_EXCESIVO);
      final resultado = await vm.crearIncidente(denuncianteId: 'den-001');

      expect(resultado, isFalse);
      expect(vm.errorMessage, contains('GPS'));
    });

    test('GeolocalizacionException al obtener posición → estado error', () async {
      when(() => geoService.solicitarPermiso())
          .thenAnswer((_) async => PermisoGpsResultado.concedido);
      when(() => geoService.obtenerPosicionActual()).thenAnswer(
        (_) => Future.error(
          const GeolocalizacionException('Timeout GPS'),
        ),
      );

      vm.seleccionarTipo(TipoIncidenteEnum.ROBOS_O_ASALTOS);
      final resultado = await vm.crearIncidente(denuncianteId: 'den-001');

      expect(resultado, isFalse);
      expect(vm.estado, CrearIncidenteEstado.error);
      expect(vm.errorMessage, 'Timeout GPS');
    });
  });

  group('crearIncidente — errores de red', () {
    test('ApiException 422 businessRule → estado error con mensaje del backend',
        () async {
      when(() => geoService.solicitarPermiso())
          .thenAnswer((_) async => PermisoGpsResultado.concedido);
      when(() => geoService.obtenerPosicionActual())
          .thenAnswer((_) async => Ubicacion(latitud: 10.391, longitud: -75.4794));
      when(() => incidenteService.crear(
            denuncianteId: any(named: 'denuncianteId'),
            tipo: any(named: 'tipo'),
            descripcion: any(named: 'descripcion'),
            ubicacion: any(named: 'ubicacion'),
          )).thenAnswer((_) => Future.error(
            const ApiException(
              type: ApiExceptionType.businessRule,
              statusCode: 422,
              message: 'Regla de negocio violada',
            ),
          ));

      vm.seleccionarTipo(TipoIncidenteEnum.ROBOS_O_ASALTOS);
      final resultado = await vm.crearIncidente(denuncianteId: 'den-001');

      expect(resultado, isFalse);
      expect(vm.estado, CrearIncidenteEstado.error);
      expect(vm.errorMessage, 'Regla de negocio violada');
    });

    test('sin conexión → estado error con mensaje de red', () async {
      when(() => geoService.solicitarPermiso())
          .thenAnswer((_) async => PermisoGpsResultado.concedido);
      when(() => geoService.obtenerPosicionActual())
          .thenAnswer((_) async => Ubicacion(latitud: 10.391, longitud: -75.4794));
      when(() => incidenteService.crear(
            denuncianteId: any(named: 'denuncianteId'),
            tipo: any(named: 'tipo'),
            descripcion: any(named: 'descripcion'),
            ubicacion: any(named: 'ubicacion'),
          )).thenAnswer((_) => Future.error(
            const ApiException(
              type: ApiExceptionType.noConnection,
              message: 'No se pudo conectar con el servidor.',
            ),
          ));

      vm.seleccionarTipo(TipoIncidenteEnum.VIOLENCIA_DOMESTICA);
      final resultado = await vm.crearIncidente(denuncianteId: 'den-001');

      expect(resultado, isFalse);
      expect(vm.estado, CrearIncidenteEstado.error);
      expect(vm.errorMessage, contains('servidor'));
    });

    test('formulario inválido (sin tipo) → devuelve false sin llamar a servicios',
        () async {
      final resultado = await vm.crearIncidente(denuncianteId: 'den-001');

      expect(resultado, isFalse);
      verifyNever(() => geoService.solicitarPermiso());
    });
  });

  group('resetear', () {
    test('vuelve al estado idle limpiando todos los campos', () async {
      when(() => geoService.solicitarPermiso())
          .thenAnswer((_) async => PermisoGpsResultado.concedido);
      when(() => geoService.obtenerPosicionActual())
          .thenAnswer((_) async => Ubicacion(latitud: 10.391, longitud: -75.4794));
      when(() => incidenteService.crear(
            denuncianteId: any(named: 'denuncianteId'),
            tipo: any(named: 'tipo'),
            descripcion: any(named: 'descripcion'),
            ubicacion: any(named: 'ubicacion'),
          )).thenAnswer((_) async => _incidenteFake());

      vm.seleccionarTipo(TipoIncidenteEnum.ROBOS_O_ASALTOS);
      vm.descripcion = 'algo';
      await vm.crearIncidente(denuncianteId: 'den-001');
      expect(vm.estado, CrearIncidenteEstado.exito);

      vm.resetear();

      expect(vm.estado, CrearIncidenteEstado.idle);
      expect(vm.tipoSeleccionado, isNull);
      expect(vm.descripcion, isEmpty);
      expect(vm.incidenteCreado, isNull);
      expect(vm.errorMessage, isNull);
      expect(vm.formularioValido, isFalse);
    });
  });
}