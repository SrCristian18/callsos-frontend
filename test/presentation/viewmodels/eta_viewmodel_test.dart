import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:CallSos/data/models/eta_info.dart';
import 'package:CallSos/data/services/incidente_service.dart';
import 'package:CallSos/data/services/stomp_service.dart';
import 'package:CallSos/presentation/viewmodels/eta_viewmodel.dart';

class MockStompService extends Mock implements IStompService {}
class MockIncidenteService extends Mock implements IIncidenteService {}

typedef OnConnected = void Function();
typedef OnError = void Function(String);

void main() {
  late MockStompService stomp;
  late MockIncidenteService incidenteService;
  late EtaViewModel vm;

  setUp(() {
    stomp = MockStompService();
    incidenteService = MockIncidenteService();
    vm = EtaViewModel(stomp: stomp, incidenteService: incidenteService);

    when(() => stomp.desconectar()).thenAnswer((_) async {});
  });

  tearDown(() => vm.dispose());

  group('iniciar — carga inicial por REST', () {
    test('consultarEta exitoso setea eta antes de que STOMP conecte', () async {
      when(() => incidenteService.consultarEta('i-001')).thenAnswer(
        (_) async => const EtaInfo(
            minutosEstimados: 8, categoriaDistancia: CategoriaDistancia.MENOS_DE_1_KM),
      );
      when(() => stomp.conectar(
            onConnected: any(named: 'onConnected'),
            onError: any(named: 'onError'),
          )).thenAnswer((_) async {});

      await vm.iniciar('i-001');

      expect(vm.eta?.minutosEstimados, 8);
      expect(vm.eta?.categoriaDistancia, CategoriaDistancia.MENOS_DE_1_KM);
    });

    test('consultarEta que falla no impide continuar con la suscripción STOMP',
        () async {
      when(() => incidenteService.consultarEta('i-001'))
          .thenThrow(Exception('Sin conexión'));
      when(() => stomp.conectar(
            onConnected: any(named: 'onConnected'),
            onError: any(named: 'onError'),
          )).thenAnswer((_) async {});

      await vm.iniciar('i-001');

      // No lanza, y sigue intentando conectar STOMP igual.
      expect(vm.eta, isNull);
      verify(() => stomp.conectar(
            onConnected: any(named: 'onConnected'),
            onError: any(named: 'onError'),
          )).called(1);
    });
  });

  group('iniciar — suscripción STOMP en tiempo real', () {
    test('al conectar, se suscribe a /topic/incidente/{id}/eta', () async {
      when(() => incidenteService.consultarEta('i-001'))
          .thenAnswer((_) async => const EtaInfo.sinDatos());

      OnConnected? capturedOnConnected;
      when(() => stomp.conectar(
            onConnected: any(named: 'onConnected'),
            onError: any(named: 'onError'),
          )).thenAnswer((inv) async {
        capturedOnConnected =
            inv.namedArguments[const Symbol('onConnected')] as OnConnected;
      });
      when(() => stomp.suscribirEta(
            incidenteId: any(named: 'incidenteId'),
            onMensaje: any(named: 'onMensaje'),
          )).thenReturn(null);

      await vm.iniciar('i-001');
      capturedOnConnected!();

      expect(vm.conexion, EtaConexionEstado.conectado);
      verify(() => stomp.suscribirEta(
            incidenteId: 'i-001',
            onMensaje: any(named: 'onMensaje'),
          )).called(1);
    });

    test('mensaje STOMP recibido actualiza eta (sobrescribe el valor de REST)',
        () async {
      when(() => incidenteService.consultarEta('i-001')).thenAnswer(
        (_) async => const EtaInfo(
            minutosEstimados: 10, categoriaDistancia: CategoriaDistancia.ENTRE_1_Y_3_KM),
      );

      OnConnected? capturedOnConnected;
      void Function(EtaInfo)? capturedOnMensaje;
      when(() => stomp.conectar(
            onConnected: any(named: 'onConnected'),
            onError: any(named: 'onError'),
          )).thenAnswer((inv) async {
        capturedOnConnected =
            inv.namedArguments[const Symbol('onConnected')] as OnConnected;
      });
      when(() => stomp.suscribirEta(
            incidenteId: any(named: 'incidenteId'),
            onMensaje: any(named: 'onMensaje'),
          )).thenAnswer((inv) {
        capturedOnMensaje = inv.namedArguments[const Symbol('onMensaje')]
            as void Function(EtaInfo);
      });

      await vm.iniciar('i-001');
      capturedOnConnected!();

      expect(vm.eta?.minutosEstimados, 10); // valor inicial por REST

      capturedOnMensaje!(const EtaInfo(
          minutosEstimados: 3, categoriaDistancia: CategoriaDistancia.MENOS_DE_1_KM));

      expect(vm.eta?.minutosEstimados, 3);
      expect(vm.eta?.categoriaDistancia, CategoriaDistancia.MENOS_DE_1_KM);
    });

    test('error de conexión STOMP → estado error + errorMessage', () async {
      when(() => incidenteService.consultarEta('i-001'))
          .thenAnswer((_) async => const EtaInfo.sinDatos());

      OnError? capturedOnError;
      when(() => stomp.conectar(
            onConnected: any(named: 'onConnected'),
            onError: any(named: 'onError'),
          )).thenAnswer((inv) async {
        capturedOnError =
            inv.namedArguments[const Symbol('onError')] as OnError;
      });

      await vm.iniciar('i-001');
      capturedOnError!('WebSocket unreachable');

      expect(vm.conexion, EtaConexionEstado.error);
      expect(vm.errorMessage, isNotNull);
    });
  });

  group('detener', () {
    test('desconecta el stomp y pasa a estado desconectado', () async {
      when(() => incidenteService.consultarEta('i-001'))
          .thenAnswer((_) async => const EtaInfo.sinDatos());
      when(() => stomp.conectar(
            onConnected: any(named: 'onConnected'),
            onError: any(named: 'onError'),
          )).thenAnswer((_) async {});

      await vm.iniciar('i-001');
      await vm.detener();

      verify(() => stomp.desconectar()).called(greaterThanOrEqualTo(1));
      expect(vm.conexion, EtaConexionEstado.desconectado);
    });
  });
}