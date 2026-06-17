import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:CallSos/data/models/valueobject/ubicacion.dart';
import 'package:CallSos/data/services/geolocalizacion_service.dart';

class MockGeolocalizacionService extends Mock
    implements IGeolocalizacionService {}

void main() {
  late MockGeolocalizacionService service;

  setUp(() {
    service = MockGeolocalizacionService();
  });

  // ─────────────────────────────────────────────────────────────────────
  // Nota sobre la estrategia de tests de F.0.6:
  //
  // GeolocalizacionService (la implementación real) usa geolocator, que
  // requiere platform channels nativos (Android/iOS) no disponibles en
  // flutter_test puro. Por eso estos tests validan el CONTRATO de la
  // interfaz IGeolocalizacionService (el "qué"), no la implementación
  // real del "cómo" (eso se valida en dispositivo físico/emulador —
  // criterio de terminado de F.0.6).
  //
  // Este patrón es el mismo que F.7 usará para mockear la geo en los
  // ViewModels que la consuman (HomeDenuncianteViewModel en F.1,
  // TrackingViewModel en F.3).
  // ─────────────────────────────────────────────────────────────────────

  group('IGeolocalizacionService — contrato de solicitarPermiso', () {
    test('devuelve concedido cuando el GPS y el permiso están disponibles',
        () async {
      when(() => service.solicitarPermiso())
          .thenAnswer((_) async => PermisoGpsResultado.concedido);

      final resultado = await service.solicitarPermiso();

      expect(resultado, PermisoGpsResultado.concedido);
    });

    test('devuelve servicioDesactivado cuando el GPS está apagado', () async {
      when(() => service.solicitarPermiso())
          .thenAnswer((_) async => PermisoGpsResultado.servicioDesactivado);

      final resultado = await service.solicitarPermiso();

      expect(resultado, PermisoGpsResultado.servicioDesactivado);
    });

    test('devuelve denegadoPermanentemente cuando el usuario bloqueó el permiso',
        () async {
      when(() => service.solicitarPermiso())
          .thenAnswer((_) async => PermisoGpsResultado.denegadoPermanentemente);

      final resultado = await service.solicitarPermiso();

      expect(resultado, PermisoGpsResultado.denegadoPermanentemente);
    });
  });

  group('IGeolocalizacionService — contrato de obtenerPosicionActual', () {
    test('devuelve una Ubicacion con coordenadas válidas (caso Cartagena)',
        () async {
      final ubicacionEsperada =
          Ubicacion(latitud: 10.391, longitud: -75.4794);

      when(() => service.obtenerPosicionActual())
          .thenAnswer((_) async => ubicacionEsperada);

      final ubicacion = await service.obtenerPosicionActual();

      expect(ubicacion.latitud, 10.391);
      expect(ubicacion.longitud, -75.4794);
      // La Ubicacion devuelta es siempre válida (validación de rango
      // garantizada por el constructor de Ubicacion — ver F.0.2).
      expect(ubicacion, isA<Ubicacion>());
    });

    test('lanza GeolocalizacionException cuando el GPS está desactivado',
        () async {
      when(() => service.obtenerPosicionActual()).thenAnswer(
        (_) => Future.error(
          const GeolocalizacionException(
            'El GPS está desactivado. Actívalo en los ajustes del dispositivo.',
          ),
        ),
      );

      await expectLater(
        service.obtenerPosicionActual(),
        throwsA(isA<GeolocalizacionException>()),
      );
    });

    test('lanza GeolocalizacionException cuando se deniega el permiso',
        () async {
      when(() => service.obtenerPosicionActual()).thenAnswer(
        (_) => Future.error(
          const GeolocalizacionException(
            'No se concedió permiso de ubicación.',
          ),
        ),
      );

      await expectLater(
        service.obtenerPosicionActual(),
        throwsA(
          isA<GeolocalizacionException>().having(
            (e) => e.message,
            'message',
            contains('permiso'),
          ),
        ),
      );
    });
  });

  group('IGeolocalizacionService — contrato de streamPosicion', () {
    test('emite Ubicacion actualizadas en el stream', () async {
      final posiciones = [
        Ubicacion(latitud: 10.391, longitud: -75.4794),
        Ubicacion(latitud: 10.392, longitud: -75.4800),
        Ubicacion(latitud: 10.393, longitud: -75.4810),
      ];

      when(() => service.streamPosicion())
          .thenAnswer((_) => Stream.fromIterable(posiciones));

      final emitidas = await service.streamPosicion().toList();

      expect(emitidas, hasLength(3));
      expect(emitidas[0].latitud, 10.391);
      expect(emitidas[2].longitud, -75.4810);
    });

    test('distanciaFiltroMetros se pasa correctamente al servicio', () async {
      when(() => service.streamPosicion(distanciaFiltroMetros: 50.0))
          .thenAnswer((_) => const Stream.empty());

      await service.streamPosicion(distanciaFiltroMetros: 50.0).toList();

      verify(() => service.streamPosicion(distanciaFiltroMetros: 50.0))
          .called(1);
    });

    test('el stream puede estar vacío sin errores (agente no se mueve)',
        () async {
      when(() => service.streamPosicion())
          .thenAnswer((_) => const Stream.empty());

      final emitidas = await service.streamPosicion().toList();

      expect(emitidas, isEmpty);
    });
  });

  group('GeolocalizacionException', () {
    test('toString incluye el mensaje', () {
      const e = GeolocalizacionException('GPS no disponible');
      expect(e.toString(), contains('GPS no disponible'));
    });
  });
}