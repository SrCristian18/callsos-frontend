import 'package:flutter_test/flutter_test.dart';
import 'package:CallSos/data/models/enums/rol.dart';

void main() {
  group('Rol — mapeo JSON / claim JWT', () {
    const todos = Rol.values;

    test('toJson() devuelve exactamente el nombre del enum (espejo backend)', () {
      final esperados = <Rol, String>{
        Rol.DENUNCIANTE: 'DENUNCIANTE',
        Rol.AGENTE: 'AGENTE',
        Rol.OPERADOR_CAI: 'OPERADOR_CAI',
        Rol.COMANDO: 'COMANDO',
      };

      for (final r in todos) {
        expect(r.toJson(), esperados[r]);
      }
    });

    test('rolFromJson() es el inverso exacto de toJson()', () {
      for (final r in todos) {
        expect(rolFromJson(r.toJson()), r);
      }
    });

    test('rolFromJson() lanza FormatException ante un valor desconocido', () {
      expect(
        () => rolFromJson('ROL_INEXISTENTE'),
        throwsFormatException,
      );
    });

    test('cada Rol tiene una etiqueta de presentación no vacía', () {
      for (final r in todos) {
        expect(r.etiqueta, isNotEmpty);
      }
    });

    test('el enum tiene exactamente 4 valores (espejo de RolUsuario backend)', () {
      expect(todos.length, 4);
    });
  });
}