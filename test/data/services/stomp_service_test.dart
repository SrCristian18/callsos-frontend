import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import 'package:CallSos/data/models/eta_info.dart';
import 'package:CallSos/data/services/stomp_service.dart';
import 'package:CallSos/data/services/token_provider.dart';

/// Épica 5 (ruta técnica) — "Test de StompService (contrato de
/// reconexión/errores)".
///
/// ACTUALIZACIÓN: este archivo documentaba antes la imposibilidad de
/// testear el ciclo de conexión real por falta de un punto de inyección
/// en `StompService`. Esa decisión se revirtió — `StompService` ahora
/// acepta una factory inyectable `creadorCliente` (ver
/// `data/services/stomp_service.dart`), y el segundo grupo de tests de
/// abajo la usa para capturar el `StompConfig` real y simular
/// manualmente los callbacks que `StompClient` invocaría al recibir
/// eventos del servidor — sin abrir un WebSocket real.
///
/// El primer grupo (parseo + "seguro de llamar en cualquier orden") se
/// mantiene igual que antes — sigue siendo válido y valioso.
void main() {
  group('UbicacionMensaje.fromJson', () {
    test('parsea un payload válido completo', () {
      final mensaje = UbicacionMensaje.fromJson({
        'latitud': 10.391,
        'longitud': -75.4794,
        'timestamp': '2026-01-01T10:00:00',
      });

      expect(mensaje.latitud, 10.391);
      expect(mensaje.longitud, -75.4794);
      expect(mensaje.timestamp, '2026-01-01T10:00:00');
    });

    test('timestamp ausente no lanza excepción, queda como string vacío', () {
      final mensaje = UbicacionMensaje.fromJson({
        'latitud': 10.391,
        'longitud': -75.4794,
      });

      expect(mensaje.timestamp, '');
    });

    test('coacciona valores enteros (int) a double', () {
      final mensaje = UbicacionMensaje.fromJson({
        'latitud': 10,
        'longitud': -75,
        'timestamp': 't',
      });

      expect(mensaje.latitud, 10.0);
      expect(mensaje.longitud, -75.0);
      expect(mensaje.latitud, isA<double>());
    });

    test('latitud/longitud ausentes lanza una excepción de tipo '
        '(el llamador es responsable de capturarla — ver StompService.suscribirUbicacionAgente)', () {
      expect(
        () => UbicacionMensaje.fromJson({'timestamp': 't'}),
        throwsA(anything),
      );
    });
  });

  group('EtaInfo.fromJson', () {
    test('parsea un payload con datos completos', () {
      final eta = EtaInfo.fromJson({
        'minutosEstimados': 8,
        'categoriaDistancia': 'MENOS_DE_1_KM',
      });

      expect(eta.minutosEstimados, 8);
      expect(eta.categoriaDistancia, CategoriaDistancia.MENOS_DE_1_KM);
      expect(eta.tieneDatos, isTrue);
    });

    test('ambos campos null (sin datos aún) no lanza excepción', () {
      final eta = EtaInfo.fromJson({
        'minutosEstimados': null,
        'categoriaDistancia': null,
      });

      expect(eta.minutosEstimados, isNull);
      expect(eta.categoriaDistancia, isNull);
      expect(eta.tieneDatos, isFalse);
    });
  });

  group('StompService — contrato defensivo (seguro de llamar en cualquier orden)', () {    test('estaConectado empieza en false', () {
      final service = StompService();
      expect(service.estaConectado, isFalse);
    });

    test('suscribirUbicacionAgente antes de conectar() no lanza excepción (no-op)', () {
      final service = StompService();

      expect(
        () => service.suscribirUbicacionAgente(
          agenteId: 'ag-001',
          onMensaje: (_) {},
        ),
        returnsNormally,
      );
    });

    test('suscribirEta antes de conectar() no lanza excepción (no-op)', () {
      final service = StompService();

      expect(
        () => service.suscribirEta(
          incidenteId: 'i-001',
          onMensaje: (_) {},
        ),
        returnsNormally,
      );
    });

    test('enviarUbicacion antes de conectar() no lanza excepción (no-op)', () {
      final service = StompService();

      expect(
        () => service.enviarUbicacion(
          incidenteId: 'i-001',
          agenteId: 'ag-001',
          latitud: 10.4,
          longitud: -75.5,
        ),
        returnsNormally,
      );
    });

    test('solicitarUltimaPosicion antes de conectar() no lanza excepción (no-op)', () {
      final service = StompService();

      expect(
        () => service.solicitarUltimaPosicion(
          incidenteId: 'i-001',
          agenteId: 'ag-001',
        ),
        returnsNormally,
      );
    });

    test('cancelarSuscripcion sin suscripción previa no lanza excepción', () {
      final service = StompService();

      expect(() => service.cancelarSuscripcion(), returnsNormally);
    });

    test('desconectar() antes de conectar() no lanza excepción y deja estaConectado en false', () async {
      final service = StompService();

      await service.desconectar();

      expect(service.estaConectado, isFalse);
    });

    test('llamar desconectar() dos veces seguidas no lanza excepción (idempotente)', () async {
      final service = StompService();

      await service.desconectar();
      await service.desconectar();

      expect(service.estaConectado, isFalse);
    });
  });

  group('StompService — contrato de reconexión/errores (StompClient inyectado)', () {
    // Con la factory inyectable (`creadorCliente`) se captura el
    // StompConfig real que StompService arma y se simulan manualmente
    // los callbacks que StompClient invocaría al recibir eventos del
    // servidor (onConnect/onStompError/onWebSocketError/onDisconnect) —
    // sin abrir un WebSocket real. El reintento automático en sí
    // (Timer interno de StompClient tras `onWebSocketDone`) es
    // responsabilidad del paquete `stomp_dart_client`, no de este
    // código; lo que SÍ es responsabilidad de StompService — y lo que
    // este grupo prueba — es que interprete y propague correctamente
    // cada evento de ciclo de vida hacia `estaConectado` y los
    // callbacks `onConnected`/`onError` que le pasa quien lo usa
    // (TrackingViewModel).
    late MockStompClient mockClient;
    late StompConfig configCapturada;

    StompService crearServicio({FakeTokenProvider? tokenProvider}) {
      return StompService(
        tokenProvider: tokenProvider,
        creadorCliente: ({required StompConfig config}) {
          configCapturada = config;
          mockClient = MockStompClient();
          when(() => mockClient.activate()).thenReturn(null);
          when(() => mockClient.deactivate()).thenReturn(null);
          return mockClient;
        },
      );
    }

    test('conectar() arma el StompConfig con reconnectDelay de 5s y heartbeats de 10s',
        () async {
      final service = crearServicio();

      await service.conectar(onConnected: () {}, onError: (_) {});

      expect(configCapturada.reconnectDelay, const Duration(seconds: 5));
      expect(configCapturada.heartbeatOutgoing, const Duration(seconds: 10));
      expect(configCapturada.heartbeatIncoming, const Duration(seconds: 10));
      verify(() => mockClient.activate()).called(1);
    });

    test('conectar() con tokenProvider agrega Authorization: Bearer <token> '
        'a los headers STOMP y WebSocket', () async {
      final service = crearServicio(tokenProvider: FakeTokenProvider('jwt-track'));

      await service.conectar(onConnected: () {}, onError: (_) {});

      expect(configCapturada.stompConnectHeaders, {'Authorization': 'Bearer jwt-track'});
      expect(configCapturada.webSocketConnectHeaders, {'Authorization': 'Bearer jwt-track'});
    });

    test('conectar() sin tokenProvider (o con token null) NO agrega header Authorization',
        () async {
      final service = crearServicio(tokenProvider: FakeTokenProvider(null));

      await service.conectar(onConnected: () {}, onError: (_) {});

      expect(configCapturada.stompConnectHeaders, isEmpty);
      expect(configCapturada.webSocketConnectHeaders, isEmpty);
    });

    test('onConnect del StompClient marca estaConectado=true y llama onConnected',
        () async {
      final service = crearServicio();
      var seLlamoOnConnected = false;

      await service.conectar(
        onConnected: () => seLlamoOnConnected = true,
        onError: (_) {},
      );
      expect(service.estaConectado, isFalse); // aún no "conectó" el server

      // Simula lo que StompClient haría al recibir el frame CONNECTED.
      configCapturada.onConnect(StompFrame(command: 'CONNECTED'));

      expect(service.estaConectado, isTrue);
      expect(seLlamoOnConnected, isTrue);
    });

    test('onStompError marca estaConectado=false y propaga frame.body como mensaje',
        () async {
      final service = crearServicio();
      String? errorRecibido;

      await service.conectar(onConnected: () {}, onError: (e) => errorRecibido = e);
      configCapturada.onConnect(StompFrame(command: 'CONNECTED')); // estaba conectado
      expect(service.estaConectado, isTrue);

      configCapturada.onStompError(
        StompFrame(command: 'ERROR', body: 'Transición de estado inválida'),
      );

      expect(service.estaConectado, isFalse);
      expect(errorRecibido, 'Transición de estado inválida');
    });

    test('onStompError con frame.body null usa el mensaje genérico de fallback', () async {
      final service = crearServicio();
      String? errorRecibido;

      await service.conectar(onConnected: () {}, onError: (e) => errorRecibido = e);
      configCapturada.onStompError(StompFrame(command: 'ERROR'));

      expect(errorRecibido, 'Error STOMP desconocido');
    });

    test('onWebSocketError marca estaConectado=false y propaga el error con prefijo',
        () async {
      final service = crearServicio();
      String? errorRecibido;

      await service.conectar(onConnected: () {}, onError: (e) => errorRecibido = e);
      configCapturada.onConnect(StompFrame(command: 'CONNECTED'));

      configCapturada.onWebSocketError('Connection refused');

      expect(service.estaConectado, isFalse);
      expect(errorRecibido, 'Error WebSocket: Connection refused');
    });

    test('onDisconnect marca estaConectado=false (sin invocar onError — '
        'es un cierre normal, no un error)', () async {
      final service = crearServicio();
      var seLlamoOnError = false;

      await service.conectar(onConnected: () {}, onError: (_) => seLlamoOnError = true);
      configCapturada.onConnect(StompFrame(command: 'CONNECTED'));
      expect(service.estaConectado, isTrue);

      configCapturada.onDisconnect(StompFrame(command: 'DISCONNECT'));

      expect(service.estaConectado, isFalse);
      expect(seLlamoOnError, isFalse);
    });

    test('llamar conectar() dos veces mientras ya está conectado no crea un segundo cliente',
        () async {
      final service = crearServicio();
      await service.conectar(onConnected: () {}, onError: (_) {});
      configCapturada.onConnect(StompFrame(command: 'CONNECTED'));
      final primerCliente = mockClient;

      await service.conectar(onConnected: () {}, onError: (_) {});

      // La factory no se volvió a invocar — mockClient sigue siendo el
      // mismo objeto capturado en la primera llamada.
      expect(mockClient, same(primerCliente));
      verify(() => mockClient.activate()).called(1); // no 2
    });

    test('enviarUbicacion mientras conectado delega en el cliente con destino y body correctos',
        () async {
      final service = crearServicio();
      when(() => mockClient.send(
            destination: any(named: 'destination'),
            body: any(named: 'body'),
          )).thenReturn(null);

      await service.conectar(onConnected: () {}, onError: (_) {});
      configCapturada.onConnect(StompFrame(command: 'CONNECTED'));

      service.enviarUbicacion(
        incidenteId: 'i-001',
        agenteId: 'ag-001',
        latitud: 10.4,
        longitud: -75.5,
      );

      final captura = verify(() => mockClient.send(
            destination: captureAny(named: 'destination'),
            body: captureAny(named: 'body'),
          )).captured;
      expect(captura[0], '/app/ubicacion/i-001');
      final body = jsonDecode(captura[1] as String) as Map<String, dynamic>;
      expect(body, {'agenteId': 'ag-001', 'latitud': 10.4, 'longitud': -75.5});
    });

    test('enviarUbicacion mientras NO conectado no llama al cliente (no-op real, '
        'no solo "no lanza excepción")', () async {
      final service = crearServicio();
      await service.conectar(onConnected: () {}, onError: (_) {});
      // OJO: nunca se simuló onConnect — sigue desconectado.

      service.enviarUbicacion(
        incidenteId: 'i-001',
        agenteId: 'ag-001',
        latitud: 10.4,
        longitud: -75.5,
      );

      verifyNever(() => mockClient.send(
            destination: any(named: 'destination'),
            body: any(named: 'body'),
          ));
    });

    test('desconectar() llama deactivate() en el cliente real y limpia el estado',
        () async {
      final service = crearServicio();
      await service.conectar(onConnected: () {}, onError: (_) {});
      configCapturada.onConnect(StompFrame(command: 'CONNECTED'));
      expect(service.estaConectado, isTrue);

      await service.desconectar();

      verify(() => mockClient.deactivate()).called(1);
      expect(service.estaConectado, isFalse);
    });

    test('suscribirUbicacionAgente se suscribe a /topic/agente/{agenteId}/ubicacion',
        () async {
      final service = crearServicio();

      await service.conectar(onConnected: () {}, onError: (_) {});
      configCapturada.onConnect(StompFrame(command: 'CONNECTED'));

      // FIX: mockClient se reasigna DENTRO de creadorCliente, que solo
      // se ejecuta al llamar conectar() — estubear antes de conectar()
      // registra el stub sobre la instancia del test ANTERIOR (o una
      // sin inicializar), no sobre la fresca de este test. Con send()
      // (void) esto pasaba desapercibido; con subscribe() (retorno no
      // nulo) explota con "type 'Null' is not a subtype of...".
      when(() => mockClient.subscribe(
            destination: any(named: 'destination'),
            callback: any(named: 'callback'),
          )).thenReturn(({Map<String, String>? unsubscribeHeaders}) {});

      service.suscribirUbicacionAgente(agenteId: 'ag-001', onMensaje: (_) {});

      final captura = verify(() => mockClient.subscribe(
            destination: captureAny(named: 'destination'),
            callback: any(named: 'callback'),
          )).captured;
      expect(captura.single, '/topic/agente/ag-001/ubicacion');
    });

    test('suscribirUbicacionAgente decodifica el frame recibido y lo pasa a onMensaje',
        () async {
      final service = crearServicio();

      await service.conectar(onConnected: () {}, onError: (_) {});
      configCapturada.onConnect(StompFrame(command: 'CONNECTED'));

      void Function(StompFrame)? callbackCapturado;
      when(() => mockClient.subscribe(
            destination: any(named: 'destination'),
            callback: any(named: 'callback'),
          )).thenAnswer((invocacion) {
        callbackCapturado =
            invocacion.namedArguments[#callback] as void Function(StompFrame);
        return ({Map<String, String>? unsubscribeHeaders}) {};
      });

      UbicacionMensaje? recibido;
      service.suscribirUbicacionAgente(
        agenteId: 'ag-001',
        onMensaje: (m) => recibido = m,
      );

      callbackCapturado!(StompFrame(
        command: 'MESSAGE',
        body: jsonEncode({
          'latitud': 10.4,
          'longitud': -75.5,
          'timestamp': '2026-01-01T10:00:00',
        }),
      ));

      expect(recibido?.latitud, 10.4);
      expect(recibido?.longitud, -75.5);
    });

    test('suscribirEta se suscribe a /topic/incidente/{incidenteId}/eta',
        () async {
      final service = crearServicio();

      await service.conectar(onConnected: () {}, onError: (_) {});
      configCapturada.onConnect(StompFrame(command: 'CONNECTED'));

      when(() => mockClient.subscribe(
            destination: any(named: 'destination'),
            callback: any(named: 'callback'),
          )).thenReturn(({Map<String, String>? unsubscribeHeaders}) {});

      service.suscribirEta(incidenteId: 'i-001', onMensaje: (_) {});

      final captura = verify(() => mockClient.subscribe(
            destination: captureAny(named: 'destination'),
            callback: any(named: 'callback'),
          )).captured;
      expect(captura.single, '/topic/incidente/i-001/eta');
    });

    test('suscribirEta decodifica el frame recibido (incluidos valores null) y lo pasa a onMensaje',
        () async {
      final service = crearServicio();

      await service.conectar(onConnected: () {}, onError: (_) {});
      configCapturada.onConnect(StompFrame(command: 'CONNECTED'));

      void Function(StompFrame)? callbackCapturado;
      when(() => mockClient.subscribe(
            destination: any(named: 'destination'),
            callback: any(named: 'callback'),
          )).thenAnswer((invocacion) {
        callbackCapturado =
            invocacion.namedArguments[#callback] as void Function(StompFrame);
        return ({Map<String, String>? unsubscribeHeaders}) {};
      });

      EtaInfo? recibido;
      service.suscribirEta(
        incidenteId: 'i-001',
        onMensaje: (m) => recibido = m,
      );

      callbackCapturado!(StompFrame(
        command: 'MESSAGE',
        body: jsonEncode({
          'minutosEstimados': 5,
          'categoriaDistancia': 'ENTRE_1_Y_3_KM',
        }),
      ));

      expect(recibido?.minutosEstimados, 5);
      expect(recibido?.categoriaDistancia, CategoriaDistancia.ENTRE_1_Y_3_KM);
    });

    test('cancelarSuscripcion cancela tanto ubicación como ETA sin lanzar excepción',
        () async {
      final service = crearServicio();

      await service.conectar(onConnected: () {}, onError: (_) {});
      configCapturada.onConnect(StompFrame(command: 'CONNECTED'));

      var canceladaUbicacion = false;
      var canceladaEta = false;
      when(() => mockClient.subscribe(
            destination: '/topic/agente/ag-001/ubicacion',
            callback: any(named: 'callback'),
          )).thenReturn(({Map<String, String>? unsubscribeHeaders}) => canceladaUbicacion = true);
      when(() => mockClient.subscribe(
            destination: '/topic/incidente/i-001/eta',
            callback: any(named: 'callback'),
          )).thenReturn(({Map<String, String>? unsubscribeHeaders}) => canceladaEta = true);

      service.suscribirUbicacionAgente(agenteId: 'ag-001', onMensaje: (_) {});
      service.suscribirEta(incidenteId: 'i-001', onMensaje: (_) {});

      service.cancelarSuscripcion();

      expect(canceladaUbicacion, isTrue);
      expect(canceladaEta, isTrue);
    });
  });
}

class MockStompClient extends Mock implements StompClient {}

class FakeTokenProvider implements ITokenProvider {
  FakeTokenProvider(this.token);
  @override
  final String? token;
}