import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:CallSos/presentation/widgets/incidente_card_skeleton.dart';

/// EPIC-15 (Microinteracciones) — skeleton loading para listas de
/// incidentes.
///
/// IMPORTANTE: `IncidenteCardSkeleton` anima con
/// `AnimationController.repeat()` (indefinido, mismo motivo que
/// `EtaWidget` documenta en su propio archivo) — ningún test acá usa
/// `pumpAndSettle()` mientras el skeleton sigue montado; solo `pump()`
/// con duraciones puntuales, o se desmonta el widget antes de
/// `pumpAndSettle()`.
void main() {
  group('IncidenteCardSkeleton', () {
    testWidgets('renderiza sin errores y anima sin lanzar excepciones',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: IncidenteCardSkeleton())),
      );
      await tester.pump();
      // Avanzar varios frames del shimmer (sin pumpAndSettle — ver
      // comentario de archivo).
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700));

      expect(tester.takeException(), isNull);
    });

    testWidgets('el AnimationController se libera sin error al desmontar',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: IncidenteCardSkeleton())),
      );
      await tester.pump();

      // Reemplazar el árbol entero desmonta el skeleton y dispara su
      // dispose(); recién ahí pumpAndSettle() es seguro (ya no queda
      // ningún AnimationController repitiendo).
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('IncidenteListSkeleton', () {
    testWidgets('muestra la cantidad de cards fantasma pedida (default 4)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: IncidenteListSkeleton())),
      );
      await tester.pump();

      expect(find.byType(IncidenteCardSkeleton), findsNWidgets(4));
    });

    testWidgets('respeta un valor de cantidad distinto', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: IncidenteListSkeleton(cantidad: 2)),
        ),
      );
      await tester.pump();

      expect(find.byType(IncidenteCardSkeleton), findsNWidgets(2));
    });

    testWidgets('no es scrolleable por su cuenta (physics fijas) — evita '
        'un doble-scroll si algún día se anida en otro scrollable',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: IncidenteListSkeleton())),
      );
      await tester.pump();

      final lista = tester.widget<ListView>(find.byType(ListView));
      expect(lista.physics, isA<NeverScrollableScrollPhysics>());
    });
  });
}