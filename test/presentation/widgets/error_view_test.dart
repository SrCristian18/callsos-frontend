import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:CallSos/presentation/widgets/error_view.dart';

void main() {
  Widget envolver(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('ErrorView — render', () {
    testWidgets('muestra el mensaje recibido', (tester) async {
      await tester.pumpWidget(envolver(
        const ErrorView(message: 'No se pudo conectar al servidor.'),
      ));

      expect(find.text('No se pudo conectar al servidor.'), findsOneWidget);
    });

    testWidgets('usa el ícono default wifi_off_outlined si no se especifica otro',
        (tester) async {
      await tester.pumpWidget(envolver(
        const ErrorView(message: 'Error'),
      ));

      expect(find.byIcon(Icons.wifi_off_outlined), findsOneWidget);
    });

    testWidgets('permite un ícono personalizado', (tester) async {
      await tester.pumpWidget(envolver(
        const ErrorView(message: 'Error', icon: Icons.error_outline),
      ));

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_outlined), findsNothing);
    });
  });

  group('ErrorView — botón de reintento', () {
    testWidgets('sin onRetry, no muestra ningún botón', (tester) async {
      await tester.pumpWidget(envolver(
        const ErrorView(message: 'Error sin acción'),
      ));

      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('con onRetry, muestra el botón con el label default "Reintentar"',
        (tester) async {
      await tester.pumpWidget(envolver(
        ErrorView(message: 'Error', onRetry: () {}),
      ));

      expect(find.widgetWithText(ElevatedButton, 'Reintentar'), findsOneWidget);
    });

    testWidgets('retryLabel personalizado se refleja en el botón', (tester) async {
      await tester.pumpWidget(envolver(
        ErrorView(message: 'Error', onRetry: () {}, retryLabel: 'Volver a intentar'),
      ));

      expect(find.widgetWithText(ElevatedButton, 'Volver a intentar'), findsOneWidget);
    });

    testWidgets('tocar el botón invoca onRetry', (tester) async {
      var llamado = false;
      await tester.pumpWidget(envolver(
        ErrorView(message: 'Error', onRetry: () => llamado = true),
      ));

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(llamado, isTrue);
    });
  });
}
