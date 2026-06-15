import 'package:flutter_test/flutter_test.dart';
import 'package:CallSos/data/models/incidente.dart';
import 'package:CallSos/data/models/enums/estado_incidente.dart';
import 'package:CallSos/data/models/enums/tipo_incidente_enum.dart';
import 'package:CallSos/data/models/valueobject/ubicacion.dart';

void main() {
  group('Incidente — fromJson (espejo de IncidenteResponse)', () {
    test('incidente recién creado (sin CAI ni nombreCAI asignados)', () {
      final json = {
        'id': 'inc-001',
        'fechaHora': '2026-06-14T10:30:00.000',
        'tipo': 'ROBOS_O_ASALTOS',
        'descripcion': 'Robo a mano armada en la esquina.',
        'estado': 'CREADO',
        'latitud': 10.391,
        'longitud': -75.4794,
        'denuncianteId': 'den-123',
        'unidadPolicialId': null,
        'nombreCAI': null,
      };

      final incidente = Incidente.fromJson(json);

      expect(incidente.id, 'inc-001');
      expect(incidente.fechaHora, DateTime.parse('2026-06-14T10:30:00.000'));
      expect(incidente.tipo, TipoIncidenteEnum.ROBOS_O_ASALTOS);
      expect(incidente.descripcion, 'Robo a mano armada en la esquina.');
      expect(incidente.estado, EstadoIncidente.CREADO);
      expect(incidente.latitud, 10.391);
      expect(incidente.longitud, -75.4794);
      expect(incidente.denuncianteId, 'den-123');
      expect(incidente.unidadPolicialId, isNull);
      expect(incidente.nombreCAI, isNull);
    });

    test('incidente ya derivado a un CAI (con unidadPolicialId y nombreCAI)', () {
      final json = {
        'id': 'inc-002',
        'fechaHora': '2026-06-14T11:00:00.000',
        'tipo': 'RIÑAS_O_PELEAS',
        'descripcion': 'Riña entre dos personas.',
        'estado': 'DERIVADO_A_CAI',
        'latitud': 10.4,
        'longitud': -75.5,
        'denuncianteId': 'den-456',
        'unidadPolicialId': 'cai-007',
        'nombreCAI': 'CAI San Francisco',
      };

      final incidente = Incidente.fromJson(json);

      // CASO CRÍTICO: el tipo "RIÑAS_O_PELEAS" (con Ñ) debe mapear
      // correctamente a TipoIncidenteEnum.RINAS_O_PELEAS.
      expect(incidente.tipo, TipoIncidenteEnum.RINAS_O_PELEAS);
      expect(incidente.estado, EstadoIncidente.DERIVADO_A_CAI);
      expect(incidente.unidadPolicialId, 'cai-007');
      expect(incidente.nombreCAI, 'CAI San Francisco');
    });
  });

  group('Incidente — toJson (round-trip)', () {
    test('fromJson -> toJson -> fromJson produce un objeto equivalente', () {
      final original = {
        'id': 'inc-003',
        'fechaHora': '2026-06-14T12:00:00.000',
        'tipo': 'INCIDENTE_DE_TRANSITO',
        'descripcion': 'Choque entre dos vehículos.',
        'estado': 'AGENTE_EN_CAMINO',
        'latitud': 10.42,
        'longitud': -75.55,
        'denuncianteId': 'den-789',
        'unidadPolicialId': 'cai-003',
        'nombreCAI': 'CAI Crespo',
      };

      final incidente = Incidente.fromJson(original);
      final reconstruido = Incidente.fromJson(incidente.toJson());

      expect(reconstruido.id, incidente.id);
      expect(reconstruido.fechaHora, incidente.fechaHora);
      expect(reconstruido.tipo, incidente.tipo);
      expect(reconstruido.descripcion, incidente.descripcion);
      expect(reconstruido.estado, incidente.estado);
      expect(reconstruido.latitud, incidente.latitud);
      expect(reconstruido.longitud, incidente.longitud);
      expect(reconstruido.denuncianteId, incidente.denuncianteId);
      expect(reconstruido.unidadPolicialId, incidente.unidadPolicialId);
      expect(reconstruido.nombreCAI, incidente.nombreCAI);
    });
  });

  group('Incidente — getters de conveniencia', () {
    final base = Incidente(
      id: 'inc-004',
      fechaHora: DateTime(2026, 6, 14, 10, 0),
      tipo: TipoIncidenteEnum.VIOLENCIA_DOMESTICA,
      descripcion: 'desc',
      estado: EstadoIncidente.EN_ATENCION,
      latitud: 10.391,
      longitud: -75.4794,
      denuncianteId: 'den-001',
    );

    test('ubicacion devuelve un Ubicacion equivalente a latitud/longitud', () {
      expect(
        base.ubicacion,
        Ubicacion(latitud: 10.391, longitud: -75.4794),
      );
    });

    test('estaActivo delega en EstadoIncidente.estaActivo', () {
      expect(base.estaActivo, isTrue); // EN_ATENCION está activo

      final finalizado = base.copyWith(estado: EstadoIncidente.FINALIZADO);
      expect(finalizado.estaActivo, isFalse);
    });

    test('copyWith solo modifica los campos indicados', () {
      final actualizado = base.copyWith(
        estado: EstadoIncidente.FINALIZADO,
        nombreCAI: 'CAI Crespo',
      );

      expect(actualizado.estado, EstadoIncidente.FINALIZADO);
      expect(actualizado.nombreCAI, 'CAI Crespo');
      // El resto de campos no cambia:
      expect(actualizado.id, base.id);
      expect(actualizado.tipo, base.tipo);
      expect(actualizado.descripcion, base.descripcion);
      expect(actualizado.latitud, base.latitud);
      expect(actualizado.longitud, base.longitud);
      expect(actualizado.denuncianteId, base.denuncianteId);
    });
  });
}