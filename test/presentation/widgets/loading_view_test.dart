import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:CallSos/presentation/widgets/loading_view.dart';

void main() {
  Widget envolver(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('LoadingView', () {
    testWidgets('muestra un CircularProgressIndicator', (tester) async {
      await tester.pumpWidget(envolver(const LoadingView()));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('sin mensaje, no muestra ningún Text', (tester) async {
      await tester.pumpWidget(envolver(const LoadingView()));

      expect(find.byType(Text), findsNothing);
    });

    testWidgets('con mensaje, lo muestra debajo del spinner', (tester) async {
      await tester.pumpWidget(envolver(
        const LoadingView(mensaje: 'Cargando incidente...'),
      ));

      expect(find.text('Cargando incidente...'), findsOneWidget);
    });

    testWidgets('no lanza ninguna excepción al renderizar', (tester) async {
      await tester.pumpWidget(envolver(
        const LoadingView(mensaje: 'X'),
      ));

      expect(tester.takeException(), isNull);
    });
  });
}
