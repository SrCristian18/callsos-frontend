import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:CallSos/data/models/enums/estado_incidente.dart';
import 'package:CallSos/data/models/enums/tipo_incidente_enum.dart';
import 'package:CallSos/data/models/incidente.dart';
import 'package:CallSos/presentation/widgets/incidente_card.dart';

/// EPIC-15 (Microinteracciones) — transición Hero entre `IncidenteCard`
/// (en la lista) y el ícono principal de `DetalleIncidenteView` (mismo
/// tag `'incidente-icono-${id}'` en ambos lados — ver el comentario de
/// cada uno). No monta `DetalleIncidenteView` real acá (requeriría todo
/// el andamiaje de servicios/sesión que ya cubre extensamente
/// detalle_incidente_view_test.dart) — en cambio, reproduce el mismo
/// contrato (una Hero con el tag esperado en cada extremo) para
/// verificar el vuelo en aislamiento.
void main() {
  Incidente incidente({String id = 'i-001'}) => Incidente(
        id: id,
        fechaHora: DateTime(2026, 6, 14, 10, 30),
        tipo: TipoIncidenteEnum.ROBOS_O_ASALTOS,
        descripcion: 'Descripción de prueba',
        estado: EstadoIncidente.CREADO,
        latitud: 10.391,
        longitud: -75.4794,
        denuncianteId: 'den-001',
      );

  group('IncidenteCard — tag de Hero', () {
    testWidgets('envuelve el ícono en un Hero con tag incidente-icono-<id>',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: IncidenteCard(incidente: incidente(id: 'i-042'))),
      ));

      final hero = tester.widget<Hero>(find.byType(Hero));
      expect(hero.tag, 'incidente-icono-i-042');
    });

    testWidgets('el tag es distinto para cada incidente (sin colisión en listas)',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              IncidenteCard(incidente: incidente(id: 'i-001')),
              IncidenteCard(incidente: incidente(id: 'i-002')),
            ],
          ),
        ),
      ));

      final tags =
          tester.widgetList<Hero>(find.byType(Hero)).map((h) => h.tag).toSet();
      expect(tags, {'incidente-icono-i-001', 'incidente-icono-i-002'});
    });
  });

  group('Vuelo Hero entre dos rutas (mismo tag)', () {
    testWidgets(
        'navegar de una pantalla con IncidenteCard a otra con el mismo tag '
        'de Hero completa el vuelo sin lanzar excepciones', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(
                      title: const Hero(
                        tag: 'incidente-icono-i-001',
                        child: Icon(Icons.warning, color: Colors.white),
                      ),
                    ),
                    body: const Text('detalle'),
                  ),
                ),
              ),
              child: IncidenteCard(incidente: incidente(id: 'i-001')),
            ),
          ),
        ),
      ));

      await tester.tap(find.byType(IncidenteCard));
      // Deliberadamente NO pumpAndSettle antes de este pump: queremos
      // capturar el vuelo A MITAD de camino (el momento más propenso a
      // un error de Hero, ej. "multiple heroes share the same tag" si
      // el origen y el destino coexistieran mal formados).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('detalle'), findsOneWidget);
    });
  });
}