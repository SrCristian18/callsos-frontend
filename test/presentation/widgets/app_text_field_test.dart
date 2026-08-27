import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:CallSos/presentation/widgets/app_text_field.dart';

void main() {
  Widget envolver(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('AppTextField — render básico', () {
    testWidgets('muestra el hintText', (tester) async {
      await tester.pumpWidget(envolver(
        const AppTextField(hintText: 'Correo electrónico'),
      ));

      expect(find.text('Correo electrónico'), findsOneWidget);
    });

    testWidgets('muestra el ícono cuando se provee', (tester) async {
      await tester.pumpWidget(envolver(
        const AppTextField(hintText: 'Correo', icon: Icons.email_outlined),
      ));

      expect(find.byIcon(Icons.email_outlined), findsOneWidget);
    });

    testWidgets('sin ícono no rompe el render', (tester) async {
      await tester.pumpWidget(envolver(
        const AppTextField(hintText: 'Sin ícono'),
      ));

      expect(tester.takeException(), isNull);
    });
  });

  group('AppTextField — entrada de texto', () {
    testWidgets('escribir texto actualiza el controller', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(envolver(
        AppTextField(hintText: 'Nombre', controller: controller),
      ));

      await tester.enterText(find.byType(TextFormField), 'Juan Pérez');

      expect(controller.text, 'Juan Pérez');
    });

    testWidgets('onChanged se invoca al escribir', (tester) async {
      String? recibido;
      await tester.pumpWidget(envolver(
        AppTextField(hintText: 'Nombre', onChanged: (v) => recibido = v),
      ));

      await tester.enterText(find.byType(TextFormField), 'X');

      expect(recibido, 'X');
    });
  });

  group('AppTextField — estado de error', () {
    testWidgets('errorText muestra el mensaje en pantalla', (tester) async {
      await tester.pumpWidget(envolver(
        const AppTextField(hintText: 'Nombre', errorText: 'Campo obligatorio'),
      ));

      expect(find.text('Campo obligatorio'), findsOneWidget);
    });

    testWidgets('sin errorText no muestra ningún mensaje de error', (tester) async {
      await tester.pumpWidget(envolver(
        const AppTextField(hintText: 'Nombre'),
      ));

      expect(find.textContaining('obligatorio'), findsNothing);
    });
  });

  group('AppTextField — estado deshabilitado', () {
    testWidgets('enabled=false deshabilita el TextFormField', (tester) async {
      await tester.pumpWidget(envolver(
        const AppTextField(hintText: 'No editable', enabled: false),
      ));

      // TextFormField no expone `enabled` como getter público propio —
      // ver la nota equivalente en app_password_field_test.dart. Se
      // inspecciona el TextField real que arma internamente.
      final campo = tester.widget<TextField>(find.byType(TextField));
      expect(campo.enabled, isFalse);
    });
  });

  group('AppTextField — accesibilidad', () {
    testWidgets('el campo tiene un Semantics label persistente (hintText)',
        (tester) async {
      await tester.pumpWidget(envolver(
        const AppTextField(hintText: 'Correo electrónico'),
      ));

      expect(find.bySemanticsLabel('Correo electrónico'), findsOneWidget);
    });
  });
}