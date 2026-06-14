import 'package:flutter_test/flutter_test.dart';
import 'package:CallSos/data/models/enums/estado_incidente.dart';

void main() {
  group('EstadoIncidente — mapeo JSON', () {
    const todos = EstadoIncidente.values;

    test('toJson() devuelve exactamente el nombre del enum (espejo backend)', () {
      final esperados = <EstadoIncidente, String>{
        EstadoIncidente.CREADO: 'CREADO',
        EstadoIncidente.DERIVADO_A_CAI: 'DERIVADO_A_CAI',
        EstadoIncidente.AGENTE_ASIGNADO: 'AGENTE_ASIGNADO',
        EstadoIncidente.AGENTE_EN_CAMINO: 'AGENTE_EN_CAMINO',
        EstadoIncidente.EN_ATENCION: 'EN_ATENCION',
        EstadoIncidente.FINALIZADO: 'FINALIZADO',
        EstadoIncidente.CANCELADO: 'CANCELADO',
      };

      for (final e in todos) {
        expect(e.toJson(), esperados[e]);
      }
    });

    test('estadoIncidenteFromJson() es el inverso exacto de toJson()', () {
      for (final e in todos) {
        expect(estadoIncidenteFromJson(e.toJson()), e);
      }
    });

    test('estadoIncidenteFromJson() lanza FormatException ante un valor desconocido', () {
      expect(
        () => estadoIncidenteFromJson('ESTADO_INEXISTENTE'),
        throwsFormatException,
      );
    });

    test('estaActivo / esTerminal — solo FINALIZADO y CANCELADO son terminales', () {
      const terminales = {
        EstadoIncidente.FINALIZADO,
        EstadoIncidente.CANCELADO,
      };

      for (final e in todos) {
        if (terminales.contains(e)) {
          expect(e.estaActivo, isFalse, reason: '$e debería ser terminal');
          expect(e.esTerminal, isTrue, reason: '$e debería ser terminal');
        } else {
          expect(e.estaActivo, isTrue, reason: '$e debería estar activo');
          expect(e.esTerminal, isFalse, reason: '$e debería estar activo');
        }
      }
    });

    test('el enum tiene exactamente 7 valores (espejo del backend)', () {
      expect(todos.length, 7);
    });
  });
}