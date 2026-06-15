import 'package:flutter_test/flutter_test.dart';
import 'package:CallSos/data/models/enums/tipo_incidente_enum.dart';
import 'package:CallSos/data/models/tipo_incidente_presentacion.dart';

void main() {
  group('TipoIncidenteEnum — mapeo JSON', () {
    const todos = TipoIncidenteEnum.values;

    test('toJson() devuelve exactamente el valor esperado por el backend', () {
      final esperados = <TipoIncidenteEnum, String>{
        TipoIncidenteEnum.RUIDO_EXCESIVO: 'RUIDO_EXCESIVO',
        TipoIncidenteEnum.ABUSO_INFANTIL: 'ABUSO_INFANTIL',
        TipoIncidenteEnum.INCIDENTE_DE_TRANSITO: 'INCIDENTE_DE_TRANSITO',
        TipoIncidenteEnum.RINAS_O_PELEAS: 'RIÑAS_O_PELEAS',
        TipoIncidenteEnum.VIOLENCIA_DOMESTICA: 'VIOLENCIA_DOMESTICA',
        TipoIncidenteEnum.ROBOS_O_ASALTOS: 'ROBOS_O_ASALTOS',
        TipoIncidenteEnum.ATENTADOS: 'ATENTADOS',
      };

      for (final t in todos) {
        expect(t.toJson(), esperados[t]);
      }
    });

    test(
      'CASO CRÍTICO: RINAS_O_PELEAS.toJson() == "RIÑAS_O_PELEAS" '
      '(el identificador Dart no puede llevar Ñ, pero el JSON sí)',
      () {
        expect(
          TipoIncidenteEnum.RINAS_O_PELEAS.toJson(),
          'RIÑAS_O_PELEAS',
        );
      },
    );

    test('tipoIncidenteFromJson() es el inverso exacto de toJson()', () {
      for (final t in todos) {
        expect(tipoIncidenteFromJson(t.toJson()), t);
      }
    });

    test('tipoIncidenteFromJson("RIÑAS_O_PELEAS") -> TipoIncidenteEnum.RINAS_O_PELEAS', () {
      expect(
        tipoIncidenteFromJson('RIÑAS_O_PELEAS'),
        TipoIncidenteEnum.RINAS_O_PELEAS,
      );
    });

    test('tipoIncidenteFromJson() lanza FormatException ante un valor desconocido', () {
      expect(
        () => tipoIncidenteFromJson('TIPO_INEXISTENTE'),
        throwsFormatException,
      );
    });

    test('el enum tiene exactamente 7 valores (espejo del backend)', () {
      expect(todos.length, 7);
    });
  });

  group('catalogoTipos — presentación', () {
    test('todos los TipoIncidenteEnum tienen entrada de presentación', () {
      for (final t in TipoIncidenteEnum.values) {
        expect(catalogoTipos.containsKey(t), isTrue,
            reason: 'Falta presentación para $t');
        expect(catalogoTipos[t]!.titulo, isNotEmpty);
        expect(catalogoTipos[t]!.descripcion, isNotEmpty);
      }
    });

    test('ATENTADOS está presente (faltaba en el catálogo anterior)', () {
      expect(catalogoTipos.containsKey(TipoIncidenteEnum.ATENTADOS), isTrue);
    });
  });
}