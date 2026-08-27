import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:CallSos/presentation/widgets/empty_state.dart';

void main() {
  Widget envolver(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('EmptyState', () {
    testWidgets('muestra el ícono y el mensaje recibidos', (tester) async {
      await tester.pumpWidget(envolver(
        const EmptyState(
          icon: Icons.inbox_outlined,
          message: 'No hay incidentes disponibles.',
        ),
      ));

      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
      expect(find.text('No hay incidentes disponibles.'), findsOneWidget);
    });

    testWidgets('sin subtitle, no muestra un segundo texto', (tester) async {
      await tester.pumpWidget(envolver(
        const EmptyState(icon: Icons.inbox_outlined, message: 'Vacío'),
      ));

      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('con subtitle, lo muestra debajo del mensaje principal',
        (tester) async {
      await tester.pumpWidget(envolver(
        const EmptyState(
          icon: Icons.inbox_outlined,
          message: 'Vacío',
          subtitle: 'Tocá + para reportar uno.',
        ),
      ));

      expect(find.text('Vacío'), findsOneWidget);
      expect(find.text('Tocá + para reportar uno.'), findsOneWidget);
    });

    testWidgets('no lanza ninguna excepción al renderizar', (tester) async {
      await tester.pumpWidget(envolver(
        const EmptyState(icon: Icons.inbox_outlined, message: 'X'),
      ));

      expect(tester.takeException(), isNull);
    });
  });
}
