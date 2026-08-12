import 'package:flutter_test/flutter_test.dart';
import 'package:CallSos/data/services/stomp_service.dart';

/// Épica 5 (ruta técnica) — "Test de StompService (contrato de
/// reconexión/errores)".
///
/// LIMITACIÓN ARQUITECTÓNICA (documentada a propósito, no un olvido):
/// `StompService._client` es un `StompClient` (paquete `stomp_dart_client`)
/// construido DENTRO de `conectar()` — no hay ningún punto de inyección
/// para reemplazarlo por un doble de prueba desde afuera. Por lo tanto,
/// el ciclo real de conexión/reconexión/heartbeat solo puede probarse
/// hoy con un servidor WebSocket real (fuera del alcance de un test
/// unitario). Si en el futuro se necesita cubrir eso, la vía es
/// refactorizar `StompService` para aceptar una factory inyectable
/// `StompClient Function(StompConfig)` — no se hace aquí para no
/// modificar comportamiento de producción sin que el equipo lo pida.
///
/// Lo que SÍ se prueba, sin red, y es exactamente lo que un "contrato de
/// errores" debe garantizar para no tumbar la UI de tracking:
///   1. `UbicacionMensaje.fromJson` — el parseo del payload STOMP.
///   2. Que el servicio sea seguro de llamar en CUALQUIER orden — en
///      particular, ANTES de `conectar()` (caso real: el usuario navega
///      fuera de `TrackingView` antes de que la conexión termine de
///      establecerse) — sin lanzar excepciones.
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
        '(el llamador es responsable de capturarla — ver StompService.suscribirUbicacion)', () {
      expect(
        () => UbicacionMensaje.fromJson({'timestamp': 't'}),
        throwsA(anything),
      );
    });
  });

  group('StompService — contrato defensivo (seguro de llamar en cualquier orden)', () {
    test('estaConectado empieza en false', () {
      final service = StompService();
      expect(service.estaConectado, isFalse);
    });

    test('suscribirUbicacion antes de conectar() no lanza excepción (no-op)', () {
      final service = StompService();

      expect(
        () => service.suscribirUbicacion(
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
}