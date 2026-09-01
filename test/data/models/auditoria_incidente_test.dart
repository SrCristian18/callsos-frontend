import 'package:flutter_test/flutter_test.dart';
import 'package:CallSos/data/models/auditoria_incidente.dart';
import 'package:CallSos/data/models/enums/estado_incidente.dart';

void main() {
  group('AuditoriaIncidente — fromJson (espejo de AuditoriaIncidente.java)', () {
    test('transición de estado normal: estadoAnterior/estadoNuevo llevan el '
        'hecho, campo/valores genéricos quedan null', () {
      final json = {
        'incidenteId': 'inc-001',
        'estadoAnterior': 'AGENTE_ASIGNADO',
        'estadoNuevo': 'AGENTE_EN_CAMINO',
        'actorId': 'ag-001',
        'actorRol': 'AGENTE',
        'timestamp': '2026-06-14T10:35:00.000',
        'detalle': 'El agente confirmó que va en camino.',
        'campo': null,
        'valorAnteriorGenerico': null,
        'valorNuevoGenerico': null,
      };

      final evento = AuditoriaIncidente.fromJson(json);

      expect(evento.incidenteId, 'inc-001');
      expect(evento.estadoAnterior, EstadoIncidente.AGENTE_ASIGNADO);
      expect(evento.estadoNuevo, EstadoIncidente.AGENTE_EN_CAMINO);
      expect(evento.actorId, 'ag-001');
      expect(evento.actorRol, 'AGENTE');
      expect(evento.timestamp, DateTime.parse('2026-06-14T10:35:00.000'));
      expect(evento.detalle, 'El agente confirmó que va en camino.');
      expect(evento.campo, isNull);
      expect(evento.valorAnteriorGenerico, isNull);
      expect(evento.valorNuevoGenerico, isNull);
      expect(evento.esCambioGenerico, isFalse);
    });

    test('creación inicial: estadoAnterior es null (no hay estado previo)', () {
      final json = {
        'incidenteId': 'inc-001',
        'estadoAnterior': null,
        'estadoNuevo': 'CREADO',
        'actorId': 'den-001',
        'actorRol': 'DENUNCIANTE',
        'timestamp': '2026-06-14T10:00:00.000',
        'detalle': 'Incidente creado.',
        'campo': null,
        'valorAnteriorGenerico': null,
        'valorNuevoGenerico': null,
      };

      final evento = AuditoriaIncidente.fromJson(json);

      expect(evento.estadoAnterior, isNull);
      expect(evento.estadoNuevo, EstadoIncidente.CREADO);
      expect(evento.esCambioGenerico, isFalse);
    });

    test('cambio de campo genérico (ej. tipo): campo/valores genéricos '
        'llevan el hecho, estadoAnterior queda null y estadoNuevo es el '
        'estado VIGENTE (no representa una transición)', () {
      final json = {
        'incidenteId': 'inc-002',
        'estadoAnterior': null,
        'estadoNuevo': 'DERIVADO_A_CAI',
        'actorId': 'den-001',
        'actorRol': 'DENUNCIANTE',
        'timestamp': '2026-06-14T10:40:00.000',
        'detalle': 'El denunciante actualizó el tipo de incidente.',
        'campo': 'tipo',
        'valorAnteriorGenerico': 'ROBOS_O_ASALTOS',
        'valorNuevoGenerico': 'RIÑAS_O_PELEAS',
      };

      final evento = AuditoriaIncidente.fromJson(json);

      expect(evento.estadoAnterior, isNull);
      expect(evento.estadoNuevo, EstadoIncidente.DERIVADO_A_CAI);
      expect(evento.campo, 'tipo');
      expect(evento.valorAnteriorGenerico, 'ROBOS_O_ASALTOS');
      expect(evento.valorNuevoGenerico, 'RIÑAS_O_PELEAS');
      expect(evento.esCambioGenerico, isTrue);
    });

    test('detalle ausente (null) se mapea a string vacío, no lanza', () {
      final json = {
        'incidenteId': 'inc-003',
        'estadoAnterior': null,
        'estadoNuevo': 'CREADO',
        'actorId': 'den-001',
        'actorRol': 'DENUNCIANTE',
        'timestamp': '2026-06-14T10:00:00.000',
        'detalle': null,
        'campo': null,
        'valorAnteriorGenerico': null,
        'valorNuevoGenerico': null,
      };

      final evento = AuditoriaIncidente.fromJson(json);

      expect(evento.detalle, '');
    });
  });
}