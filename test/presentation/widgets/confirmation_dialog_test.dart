import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:CallSos/presentation/widgets/confirmation_dialog.dart';

void main() {
  /// Botón que abre el diálogo y guarda el resultado en [resultado] —
  /// mismo patrón que usaría cualquier vista real (`await
  /// ConfirmationDialog.show(...)` dentro de un handler).
  Widget envolver({
    required ValueNotifier<bool?> resultado,
    bool isDangerous = false,
    bool barrierDismissible = false,
    String confirmText = 'Confirmar',
    String cancelText = 'Cancelar',
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              resultado.value = await ConfirmationDialog.show(
                context,
                title: 'Título de prueba',
                message: 'Mensaje de prueba',
                confirmText: confirmText,
                cancelText: cancelText,
                isDangerous: isDangerous,
                barrierDismissible: barrierDismissible,
              );
            },
            child: const Text('Abrir'),
          ),
        ),
      ),
    );
  }

  group('ConfirmationDialog — render', () {
    testWidgets('muestra título, mensaje y ambos botones', (tester) async {
      final resultado = ValueNotifier<bool?>(null);
      await tester.pumpWidget(envolver(resultado: resultado));

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Título de prueba'), findsOneWidget);
      expect(find.text('Mensaje de prueba'), findsOneWidget);
      expect(find.text('Confirmar'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
    });

    testWidgets('usa los textos personalizados de confirmText/cancelText',
        (tester) async {
      final resultado = ValueNotifier<bool?>(null);
      await tester.pumpWidget(envolver(
        resultado: resultado,
        confirmText: 'Sí, cancelar',
        cancelText: 'No, volver',
      ));

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Sí, cancelar'), findsOneWidget);
      expect(find.text('No, volver'), findsOneWidget);
    });
  });

  group('ConfirmationDialog — resultado true/false', () {
    testWidgets('tocar confirmar devuelve true', (tester) async {
      final resultado = ValueNotifier<bool?>(null);
      await tester.pumpWidget(envolver(resultado: resultado));
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(resultado.value, isTrue);
    });

    testWidgets('tocar cancelar devuelve false (nunca null)', (tester) async {
      final resultado = ValueNotifier<bool?>(null);
      await tester.pumpWidget(envolver(resultado: resultado));
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(resultado.value, isFalse);
    });

    testWidgets(
        'barrierDismissible=false (default): tocar afuera NO cierra el diálogo',
        (tester) async {
      final resultado = ValueNotifier<bool?>(null);
      await tester.pumpWidget(envolver(resultado: resultado));
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      // Toca una esquina fuera del AlertDialog.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      // Sigue abierto — el resultado nunca llegó a resolverse.
      expect(find.text('Título de prueba'), findsOneWidget);
      expect(resultado.value, isNull);
    });

    testWidgets(
        'barrierDismissible=true: tocar afuera cierra el diálogo con false',
        (tester) async {
      final resultado = ValueNotifier<bool?>(null);
      await tester.pumpWidget(
          envolver(resultado: resultado, barrierDismissible: true));
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(find.text('Título de prueba'), findsNothing);
      expect(resultado.value, isFalse);
    });
  });

  group('ConfirmationDialog — isDangerous', () {
    testWidgets('isDangerous=true colorea el botón de confirmar en rojo (error)',
        (tester) async {
      final resultado = ValueNotifier<bool?>(null);
      await tester.pumpWidget(envolver(resultado: resultado, isDangerous: true));
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      final boton = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Confirmar'),
          matching: find.byType(TextButton),
        ),
      );
      final color = boton.style!.foregroundColor!.resolve({});
      expect(color, const Color(0xFFD32F2F)); // AppColors.error
    });

    testWidgets('isDangerous=false (default) NO usa el color de error',
        (tester) async {
      final resultado = ValueNotifier<bool?>(null);
      await tester.pumpWidget(envolver(resultado: resultado));
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      final boton = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Confirmar'),
          matching: find.byType(TextButton),
        ),
      );
      final color = boton.style!.foregroundColor!.resolve({});
      expect(color, isNot(const Color(0xFFD32F2F)));
    });
  });

  group('ConfirmationDialog — EPIC-15 (haptic feedback)', () {
    // `HapticFeedback.*` invoca el método 'HapticFeedback.vibrate' en el
    // canal `SystemChannels.platform` ('flutter/platform'). Capturamos
    // las llamadas con un mock handler para verificar que se dispare
    // exactamente al confirmar, y NO al cancelar ni al abrir el diálogo.
    final llamadas = <MethodCall>[];

    setUp(() {
      llamadas.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        llamadas.add(call);
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('tocar Confirmar dispara HapticFeedback.vibrate (mediumImpact)',
        (tester) async {
      final resultado = ValueNotifier<bool?>(null);
      await tester.pumpWidget(envolver(resultado: resultado));
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      // Abrir el diálogo ya dispara OTRAS llamadas legítimas por el
      // mismo canal ('flutter/platform') — SystemSound.play (el click
      // del botón que abre) y SystemChrome.setApplicationSwitcherDescription
      // (housekeeping normal de MaterialApp) — así que la aserción acá
      // filtra específicamente por 'HapticFeedback.vibrate', no por
      // "ninguna llamada en absoluto".
      expect(llamadas.where((c) => c.method == 'HapticFeedback.vibrate'),
          isEmpty);

      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      final vibraciones =
          llamadas.where((c) => c.method == 'HapticFeedback.vibrate');
      expect(vibraciones, hasLength(1));
      expect(vibraciones.first.arguments, 'HapticFeedbackType.mediumImpact');
    });

    testWidgets('tocar Cancelar NO dispara HapticFeedback', (tester) async {
      final resultado = ValueNotifier<bool?>(null);
      await tester.pumpWidget(envolver(resultado: resultado));
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(llamadas.where((c) => c.method == 'HapticFeedback.vibrate'),
          isEmpty);
    });
  });
}