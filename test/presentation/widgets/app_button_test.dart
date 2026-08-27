import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:CallSos/presentation/widgets/app_button.dart';

void main() {
  Widget envolver(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('AppButton — render básico', () {
    testWidgets('muestra el label recibido', (tester) async {
      await tester.pumpWidget(envolver(
        AppButton(label: 'Continuar', onPressed: () {}),
      ));

      expect(find.text('Continuar'), findsOneWidget);
    });

    testWidgets('muestra el ícono cuando se provee', (tester) async {
      await tester.pumpWidget(envolver(
        AppButton(label: 'Reintentar', icon: Icons.refresh, onPressed: () {}),
      ));

      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });

  group('AppButton — interacción', () {
    testWidgets('onPressed se invoca al tocar', (tester) async {
      var toques = 0;
      await tester.pumpWidget(envolver(
        AppButton(label: 'Tocar', onPressed: () => toques++),
      ));

      await tester.tap(find.byType(AppButton));
      await tester.pump();

      expect(toques, 1);
    });

    testWidgets('onPressed null deshabilita el botón (no lanza al tocar)',
        (tester) async {
      await tester.pumpWidget(envolver(
        const AppButton(label: 'Deshabilitado', onPressed: null),
      ));

      final boton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(boton.onPressed, isNull);
    });
  });

  group('AppButton — isLoading (fix del salto de layout)', () {
    testWidgets('reemplaza el texto por un spinner, oculta el ícono',
        (tester) async {
      await tester.pumpWidget(envolver(
        AppButton(
          label: 'Enviando',
          icon: Icons.send,
          isLoading: true,
          onPressed: () {},
        ),
      ));

      expect(find.text('Enviando'), findsNothing);
      expect(find.byIcon(Icons.send), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('isLoading ignora onPressed aunque no sea null', (tester) async {
      var toques = 0;
      await tester.pumpWidget(envolver(
        AppButton(label: 'Enviando', isLoading: true, onPressed: () => toques++),
      ));

      final boton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(boton.onPressed, isNull);
      expect(toques, 0);
    });

    testWidgets(
        'el botón mantiene el mismo tamaño con y sin isLoading (sin salto de layout)',
        (tester) async {
      await tester.pumpWidget(envolver(
        AppButton(label: 'Enviar', onPressed: () {}),
      ));
      final tamanoNormal = tester.getSize(find.byType(ElevatedButton));

      await tester.pumpWidget(envolver(
        AppButton(label: 'Enviar', isLoading: true, onPressed: () {}),
      ));
      final tamanoCargando = tester.getSize(find.byType(ElevatedButton));

      expect(tamanoCargando, tamanoNormal);
    });
  });

  group('AppButton — variantes', () {
    testWidgets('primary usa fondo verdeOscuro', (tester) async {
      await tester.pumpWidget(envolver(
        AppButton(label: 'X', onPressed: () {}),
      ));
      final estilo =
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).style!;
      final color = estilo.backgroundColor!.resolve({});
      expect(color, const Color(0xff1e9a20));
    });

    testWidgets('outlined usa fondo transparente y tiene borde', (tester) async {
      await tester.pumpWidget(envolver(
        AppButton(
            label: 'X', variant: AppButtonVariant.outlined, onPressed: () {}),
      ));
      final estilo =
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).style!;
      expect(estilo.backgroundColor!.resolve({}), Colors.transparent);
      expect(estilo.side!.resolve({}), isNotNull);
    });

    testWidgets('danger usa el color de error', (tester) async {
      await tester.pumpWidget(envolver(
        AppButton(
            label: 'X', variant: AppButtonVariant.danger, onPressed: () {}),
      ));
      final estilo =
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).style!;
      expect(estilo.backgroundColor!.resolve({}), const Color(0xFFD32F2F));
    });
  });

  group('AppButton — fullWidth', () {
    testWidgets('fullWidth=true (default) usa minimumSize infinito',
        (tester) async {
      await tester.pumpWidget(envolver(
        AppButton(label: 'X', onPressed: () {}),
      ));
      final estilo =
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).style!;
      expect(estilo.minimumSize!.resolve({})!.width, double.infinity);
    });

    testWidgets('fullWidth=false no fuerza minimumSize', (tester) async {
      await tester.pumpWidget(envolver(
        AppButton(label: 'X', fullWidth: false, onPressed: () {}),
      ));
      final estilo =
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).style!;
      expect(estilo.minimumSize, isNull);
    });
  });

  group('AppButton — accesibilidad', () {
    testWidgets('el Semantics anuncia "cargando" mientras isLoading',
        (tester) async {
      await tester.pumpWidget(envolver(
        AppButton(label: 'Enviar', isLoading: true, onPressed: () {}),
      ));

      expect(find.bySemanticsLabel('Enviar, cargando'), findsOneWidget);
    });
  });
}
