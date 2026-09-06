import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:CallSos/presentation/widgets/app_password_field.dart';

/// EPIC-19 (verificación de accesibilidad) — este archivo antes
/// importaba y testeaba `AppTextField`, no `AppPasswordField` (copiado
/// del archivo gemelo y nunca corregido) — cero cobertura real para el
/// widget que le da nombre al archivo, incluyendo el toggle de mostrar/
/// ocultar contraseña, que es la razón de ser de este componente (ver
/// el comentario de clase de `AppPasswordField` sobre el bug que
/// corrige en `CustomInput`). Reescrito para testear el widget real.
void main() {
  Widget envolver(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('AppPasswordField — render básico', () {
    testWidgets('muestra el hintText', (tester) async {
      await tester.pumpWidget(envolver(
        const AppPasswordField(hintText: 'Contraseña'),
      ));

      expect(find.text('Contraseña'), findsOneWidget);
    });

    testWidgets('el ícono por defecto es un candado', (tester) async {
      await tester.pumpWidget(envolver(
        const AppPasswordField(hintText: 'Contraseña'),
      ));

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('acepta un ícono distinto', (tester) async {
      await tester.pumpWidget(envolver(
        const AppPasswordField(hintText: 'PIN', icon: Icons.pin_outlined),
      ));

      expect(find.byIcon(Icons.pin_outlined), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsNothing);
    });
  });

  group('AppPasswordField — entrada de texto', () {
    testWidgets('escribir texto actualiza el controller', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(envolver(
        AppPasswordField(hintText: 'Contraseña', controller: controller),
      ));

      await tester.enterText(find.byType(TextFormField), 'Secreta123');

      expect(controller.text, 'Secreta123');
    });

    testWidgets('onChanged se invoca al escribir', (tester) async {
      String? recibido;
      await tester.pumpWidget(envolver(
        AppPasswordField(hintText: 'Contraseña', onChanged: (v) => recibido = v),
      ));

      await tester.enterText(find.byType(TextFormField), 'X');

      expect(recibido, 'X');
    });
  });

  group('AppPasswordField — mostrar/ocultar contraseña (el bug que corrige)', () {
    testWidgets('por defecto el texto está oculto (obscureText: true)',
        (tester) async {
      await tester.pumpWidget(envolver(
        const AppPasswordField(hintText: 'Contraseña'),
      ));

      // `TextFormField` no expone `obscureText` como campo público (arma
      // un `EditableText` internamente) — se verifica ahí.
      final campo = tester.widget<EditableText>(find.byType(EditableText));
      expect(campo.obscureText, isTrue);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('tocar el ícono revela el texto y cambia a un ícono distinto',
        (tester) async {
      await tester.pumpWidget(envolver(
        const AppPasswordField(hintText: 'Contraseña'),
      ));

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();

      final campo = tester.widget<EditableText>(find.byType(EditableText));
      expect(campo.obscureText, isFalse);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);
    });

    testWidgets('tocar el ícono de nuevo vuelve a ocultar el texto',
        (tester) async {
      await tester.pumpWidget(envolver(
        const AppPasswordField(hintText: 'Contraseña'),
      ));

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();

      final campo = tester.widget<EditableText>(find.byType(EditableText));
      expect(campo.obscureText, isTrue);
    });

    testWidgets('el tooltip del ícono cambia según el estado', (tester) async {
      await tester.pumpWidget(envolver(
        const AppPasswordField(hintText: 'Contraseña'),
      ));

      expect(find.byTooltip('Mostrar contraseña'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();

      expect(find.byTooltip('Ocultar contraseña'), findsOneWidget);
    });

    testWidgets('enabled=false también deshabilita el toggle', (tester) async {
      await tester.pumpWidget(envolver(
        const AppPasswordField(hintText: 'Contraseña', enabled: false),
      ));

      final boton = tester.widget<IconButton>(find.byType(IconButton));
      expect(boton.onPressed, isNull);
    });
  });

  group('AppPasswordField — estado de error', () {
    testWidgets('errorText muestra el mensaje en pantalla', (tester) async {
      await tester.pumpWidget(envolver(
        const AppPasswordField(
            hintText: 'Contraseña', errorText: 'Mínimo 6 caracteres'),
      ));

      expect(find.text('Mínimo 6 caracteres'), findsOneWidget);
    });

    testWidgets('sin errorText no muestra ningún mensaje de error', (tester) async {
      await tester.pumpWidget(envolver(
        const AppPasswordField(hintText: 'Contraseña'),
      ));

      expect(find.textContaining('caracteres'), findsNothing);
    });
  });

  group('AppPasswordField — estado deshabilitado', () {
    testWidgets('enabled=false deshabilita el TextFormField', (tester) async {
      await tester.pumpWidget(envolver(
        const AppPasswordField(hintText: 'Contraseña', enabled: false),
      ));

      final campo = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(campo.enabled, isFalse);
    });
  });

  group('AppPasswordField — accesibilidad', () {
    testWidgets('el campo tiene un Semantics label persistente (hintText)',
        (tester) async {
      // EPIC-19: `excludeSemantics: true` se mantiene en el widget —
      // se probó sacarlo y CONFIRMÓ (con un test real, no una
      // suposición) que el label desaparece por completo en vez de
      // duplicarse. Ver el comentario en AppPasswordField.build().
      await tester.pumpWidget(envolver(
        const AppPasswordField(hintText: 'Contraseña'),
      ));

      expect(find.bySemanticsLabel('Contraseña'), findsOneWidget);
    });
  });

  group('AppPasswordField — límite conocido de este archivo (no un test)', () {
    // NO hay un test acá para "el tooltip del toggle no llega al lector
    // de pantalla mientras excludeSemantics esté activo" — se intentó
    // escribir uno con `find.byTooltip(...)` y HABRÍA FALLADO por el
    // motivo equivocado: `find.byTooltip` busca un widget `Tooltip` con
    // ese `message` en el árbol de WIDGETS, sin mirar el árbol de
    // semántica en absoluto (así está implementado en flutter_test) —
    // encuentra el tooltip esté o no excluido de la accesibilidad real.
    // Un widget test con las herramientas de `flutter_test` no puede
    // confirmar ni refutar esto; solo un lector de pantalla real puede
    // — ver docs/verificacion_accesibilidad_manual.md.
  });
}