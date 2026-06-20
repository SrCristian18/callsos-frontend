import 'package:flutter_test/flutter_test.dart';
import 'package:CallSos/data/models/valueobject/ubicacion.dart';

void main() {
  group('Ubicacion — construcción y validación', () {
    test('acepta coordenadas válidas (Cartagena, Colombia)', () {
      final u = Ubicacion(latitud: 10.391, longitud: -75.4794);
      expect(u.latitud, 10.391);
      expect(u.longitud, -75.4794);
    });

    test('acepta los límites exactos del rango', () {
      expect(() => Ubicacion(latitud: 90, longitud: 180), returnsNormally);
      expect(() => Ubicacion(latitud: -90, longitud: -180), returnsNormally);
    });

    test('lanza ArgumentError si la latitud está fuera de [-90, 90]', () {
      expect(() => Ubicacion(latitud: 90.1, longitud: 0), throwsArgumentError);
      expect(() => Ubicacion(latitud: -90.1, longitud: 0), throwsArgumentError);
    });

    test('lanza ArgumentError si la longitud está fuera de [-180, 180]', () {
      expect(() => Ubicacion(latitud: 0, longitud: 180.1), throwsArgumentError);
      expect(() => Ubicacion(latitud: 0, longitud: -180.1), throwsArgumentError);
    });
  });

  group('Ubicacion — mapeo JSON', () {
    test('fromJson / toJson son inversos (round-trip)', () {
      final json = {'latitud': 10.391, 'longitud': -75.4794};
      final u = Ubicacion.fromJson(json);

      expect(u.latitud, 10.391);
      expect(u.longitud, -75.4794);
      expect(u.toJson(), json);
    });

    test('fromJson acepta números enteros (JSON sin parte decimal)', () {
      final u = Ubicacion.fromJson({'latitud': 10, 'longitud': -75});
      expect(u.latitud, 10.0);
      expect(u.longitud, -75.0);
    });
  });

  group('Ubicacion — igualdad por valor', () {
    test('dos ubicaciones con las mismas coordenadas son iguales', () {
      final a = Ubicacion(latitud: 10.391, longitud: -75.4794);
      final b = Ubicacion(latitud: 10.391, longitud: -75.4794);

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('ubicaciones con coordenadas distintas no son iguales', () {
      final a = Ubicacion(latitud: 10.391, longitud: -75.4794);
      final b = Ubicacion(latitud: 10.4, longitud: -75.4794);

      expect(a, isNot(equals(b)));
    });
  });
}