import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:CallSos/data/models/enums/rol.dart';
import 'package:CallSos/data/models/valueobject/ubicacion.dart';
import 'package:CallSos/data/services/geolocalizacion_service.dart';
import 'package:CallSos/data/services/stomp_service.dart';
import 'package:CallSos/presentation/viewmodels/tracking_viewmodel.dart';

class MockStompService extends Mock implements IStompService {}
class MockGeoService extends Mock implements IGeolocalizacionService {}

// Callback capturado del onConnected para simular la conexión exitosa
typedef OnConnected = void Function();
typedef OnError = void Function(String);

void main() {
  late MockStompService stomp;
  late MockGeoService geo;
  late TrackingViewModel vm;

  setUp(() {
    stomp = MockStompService();
    geo = MockGeoService();
    vm = TrackingViewModel(stomp: stomp, geo: geo);

    // Defaults: estaConectado empieza en false
    when(() => stomp.estaConectado).thenReturn(false);
    when(() => stomp.desconectar()).thenAnswer((_) async {});
    when(() => stomp.cancelarSuscripcion()).thenReturn(null);
  });

  tearDown(() => vm.dispose());

  group('iniciar — estado de conexión', () {
    test('pasa a conectando al llamar iniciar', () async {
      when(() => stomp.conectar(
            onConnected: any(named: 'onConnected'),
            onError: any(named: 'onError'),
          )).thenAnswer((_) async {});

      // No await completo — solo disparar
      unawaited(vm.iniciar(
        incidenteId: 'inc-001',
        rol: Rol.DENUNCIANTE,
        actorId: 'den-001',
      ));

      expect(vm.conexion, TrackingConexionEstado.conectando);
    });

    test('error de conexión → estado error + errorMessage', () async {
      OnError? capturedOnError;

      when(() => stomp.conectar(
            onConnected: any(named: 'onConnected'),
            onError: any(named: 'onError'),
          )).thenAnswer((invocation) async {
        capturedOnError =
            invocation.namedArguments[const Symbol('onError')] as OnError;
      });

      await vm.iniciar(
        incidenteId: 'inc-001',
        rol: Rol.DENUNCIANTE,
        actorId: 'den-001',
      );

      capturedOnError!('WebSocket unreachable');

      expect(vm.conexion, TrackingConexionEstado.error);
      expect(vm.errorMessage, contains('tracking'));
    });
  });

  group('modo DENUNCIANTE (receptor)', () {
    late OnConnected capturedOnConnected;
    late void Function(UbicacionMensaje) capturedOnMensaje;

    setUp(() {
      when(() => stomp.conectar(
            onConnected: any(named: 'onConnected'),
            onError: any(named: 'onError'),
          )).thenAnswer((inv) async {
        capturedOnConnected =
            inv.namedArguments[const Symbol('onConnected')] as OnConnected;
      });

      when(() => stomp.suscribirUbicacion(
            incidenteId: any(named: 'incidenteId'),
            onMensaje: any(named: 'onMensaje'),
          )).thenAnswer((inv) {
        capturedOnMensaje = inv.namedArguments[const Symbol('onMensaje')]
            as void Function(UbicacionMensaje);
      });

      when(() => stomp.solicitarUltimaPosicion(
            incidenteId: any(named: 'incidenteId'),
            agenteId: any(named: 'agenteId'),
          )).thenReturn(null);
    });

    test('al conectar suscribe al topic y solicita última posición', () async {
      await vm.iniciar(
        incidenteId: 'inc-001',
        rol: Rol.DENUNCIANTE,
        actorId: 'den-001',
      );
      capturedOnConnected();

      expect(vm.conexion, TrackingConexionEstado.conectado);

      verify(() => stomp.suscribirUbicacion(
            incidenteId: 'inc-001',
            onMensaje: any(named: 'onMensaje'),
          )).called(1);

      verify(() => stomp.solicitarUltimaPosicion(
            incidenteId: 'inc-001',
            agenteId: any(named: 'agenteId'),
          )).called(1);
    });

    test('mensaje STOMP recibido actualiza posicionAgente', () async {
      await vm.iniciar(
        incidenteId: 'inc-001',
        rol: Rol.DENUNCIANTE,
        actorId: 'den-001',
      );
      capturedOnConnected();

      capturedOnMensaje(UbicacionMensaje(
        latitud: 10.391,
        longitud: -75.4794,
        timestamp: '2026-06-14T10:00:00Z',
      ));

      expect(vm.posicionAgente, isNotNull);
      expect(vm.posicionAgente!.latitude, 10.391);
      expect(vm.posicionAgente!.longitude, -75.4794);
    });

    test('múltiples mensajes actualizan la posición con cada uno', () async {
      await vm.iniciar(
        incidenteId: 'inc-001',
        rol: Rol.DENUNCIANTE,
        actorId: 'den-001',
      );
      capturedOnConnected();

      capturedOnMensaje(UbicacionMensaje(
          latitud: 10.391, longitud: -75.4794, timestamp: ''));
      capturedOnMensaje(UbicacionMensaje(
          latitud: 10.395, longitud: -75.480, timestamp: ''));

      expect(vm.posicionAgente!.latitude, 10.395);
      expect(vm.posicionAgente!.longitude, -75.480);
    });
  });

  group('modo AGENTE (emisor)', () {
    late OnConnected capturedOnConnected;
    late StreamController<Ubicacion> gpsController;

    setUp(() {
      gpsController = StreamController<Ubicacion>();

      when(() => stomp.conectar(
            onConnected: any(named: 'onConnected'),
            onError: any(named: 'onError'),
          )).thenAnswer((inv) async {
        capturedOnConnected =
            inv.namedArguments[const Symbol('onConnected')] as OnConnected;
      });

      when(() => stomp.suscribirUbicacion(
            incidenteId: any(named: 'incidenteId'),
            onMensaje: any(named: 'onMensaje'),
          )).thenReturn(null);

      when(() => stomp.solicitarUltimaPosicion(
            incidenteId: any(named: 'incidenteId'),
            agenteId: any(named: 'agenteId'),
          )).thenReturn(null);

      when(() => stomp.enviarUbicacion(
            incidenteId: any(named: 'incidenteId'),
            agenteId: any(named: 'agenteId'),
            latitud: any(named: 'latitud'),
            longitud: any(named: 'longitud'),
          )).thenReturn(null);

      when(() => geo.streamPosicion(distanciaFiltroMetros: any(named: 'distanciaFiltroMetros')))
          .thenAnswer((_) => gpsController.stream);
    });

    tearDown(() => gpsController.close());

    test('al conectar inicia streamPosicion y envía cada posición al broker',
        () async {
      await vm.iniciar(
        incidenteId: 'inc-001',
        rol: Rol.AGENTE,
        actorId: 'agente-001',
      );
      capturedOnConnected();

      // Simular dos actualizaciones de GPS
      gpsController.add(Ubicacion(latitud: 10.391, longitud: -75.4794));
      gpsController.add(Ubicacion(latitud: 10.392, longitud: -75.480));
      await Future.delayed(Duration.zero); // dejar al stream procesar

      verify(() => stomp.enviarUbicacion(
            incidenteId: 'inc-001',
            agenteId: 'agente-001',
            latitud: 10.391,
            longitud: -75.4794,
          )).called(1);

      verify(() => stomp.enviarUbicacion(
            incidenteId: 'inc-001',
            agenteId: 'agente-001',
            latitud: 10.392,
            longitud: -75.480,
          )).called(1);
    });

    test('posicionAgente se actualiza localmente sin esperar eco del broker',
        () async {
      await vm.iniciar(
        incidenteId: 'inc-001',
        rol: Rol.AGENTE,
        actorId: 'agente-001',
      );
      capturedOnConnected();

      gpsController.add(Ubicacion(latitud: 10.395, longitud: -75.485));
      await Future.delayed(Duration.zero);

      expect(vm.posicionAgente, isNotNull);
      expect(vm.posicionAgente!.latitude, 10.395);
    });
  });

  group('detener', () {
    test('desconecta el stomp y pasa a estado desconectado', () async {
      when(() => stomp.conectar(
            onConnected: any(named: 'onConnected'),
            onError: any(named: 'onError'),
          )).thenAnswer((_) async {});

      await vm.iniciar(
        incidenteId: 'inc-001',
        rol: Rol.DENUNCIANTE,
        actorId: 'den-001',
      );

      await vm.detener();

      verify(() => stomp.desconectar()).called(greaterThanOrEqualTo(1));
      expect(vm.conexion, TrackingConexionEstado.desconectado);
    });
  });
}