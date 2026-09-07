import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:CallSos/presentation/widgets/custom_input.dart';

/// EPIC-20 (deuda técnica, hallazgo #11) — antes de esta épica,
/// `CustomInput` no tenía NINGÚN test (este archivo es nuevo).
///
/// Nota sobre qué se puede verificar desde un test de caja negra:
/// `CustomInput` ahora es `StatefulWidget` con un `State` privado — no
/// hay forma de tomar una referencia directa al `TextEditingController`
/// interno desde afuera para confirmar literalmente que `dispose()` se
/// le llamó (eso requeriría exponer el controller como API pública,
/// rompiendo el encapsulamiento que el widget necesita). En su lugar,
/// estos tests verifican el CONTRATO observable:
/// - Sin controller explícito, el texto escrito sobrevive a un rebuild
///   del padre (la manifestación real y visible del bug original — con
///   la versión vieja del widget, este test fallaría: cada rebuild
///   creaba un controller nuevo y vacío).
/// - Con un controller explícito, ese controller sigue USABLE después
///   de desmontar `CustomInput` (prueba de que no se lo dispuso — si
///   `CustomInput` lo hubiera liberado indebidamente, usarlo después
///   lanzaría "A TextEditingController was used after being disposed").
void main() {
  Widget envolver(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('CustomInput — render básico', () {
    testWidgets('muestra el hintText y el ícono', (tester) async {
      await tester.pumpWidget(envolver(
        const CustomInput(hintText: 'Correo electrónico', icon: Icons.email),
      ));

      expect(find.text('Correo electrónico'), findsOneWidget);
      expect(find.byIcon(Icons.email), findsOneWidget);
    });

    testWidgets('isPassword: true oculta el texto y muestra el ícono de ojo',
        (tester) async {
      await tester.pumpWidget(envolver(
        const CustomInput(
            hintText: 'Contraseña', icon: Icons.lock, isPassword: true),
      ));

      final campo = tester.widget<EditableText>(find.byType(EditableText));
      expect(campo.obscureText, isTrue);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });
  });

  group('CustomInput — sin controller explícito (el caso del bug)', () {
    testWidgets('escribir texto funciona igual que con un controller pasado',
        (tester) async {
      await tester.pumpWidget(envolver(
        const CustomInput(hintText: 'Correo electrónico', icon: Icons.email),
      ));

      await tester.enterText(find.byType(TextField), 'hola@test.com');
      await tester.pump();

      expect(find.text('hola@test.com'), findsOneWidget);
    });

    testWidgets(
        'FIX EPIC-20: el texto escrito sobrevive a un rebuild del padre '
        '(antes de esta épica, cada rebuild creaba un controller interno '
        'nuevo y vacío, perdiendo lo que el usuario ya había escrito)',
        (tester) async {
      // `StatefulBuilder` deja forzar un rebuild del PADRE de
      // `CustomInput` sin recrear el `State` de `CustomInput` en sí
      // (mismo árbol de widgets, mismo Element) — exactamente el
      // escenario real que rompía con la versión vieja: un
      // `setState()` en cualquier ancestro (ej. una notificación de
      // Provider) que no tiene nada que ver con este campo puntual.
      //
      // Deliberadamente SIN `const` en el CustomInput de acá abajo: un
      // `const CustomInput(...)` sería el MISMO objeto (idéntico) en
      // cada rebuild del padre, y Flutter salta por completo la
      // reconstrucción de un widget hijo idéntico — eso hubiera
      // enmascarado el bug en vez de probarlo (de hecho, así es como
      // `forgot_password_view.dart` se salvó del bug por accidente: es
      // el único uso sin controller, y usa `const`). Sin `const`, cada
      // rebuild construye una instancia NUEVA de `CustomInput`, que es
      // el caso real que rompía antes del fix.
      late StateSetter rebuildPadre;
      await tester.pumpWidget(envolver(
        StatefulBuilder(
          builder: (context, setState) {
            rebuildPadre = setState;
            return CustomInput(hintText: 'Correo', icon: Icons.email);
          },
        ),
      ));

      await tester.enterText(find.byType(TextField), 'usuario@test.com');
      await tester.pump();
      expect(find.text('usuario@test.com'), findsOneWidget);

      // Forzar un rebuild del padre — no del campo en sí.
      rebuildPadre(() {});
      await tester.pump();

      expect(find.text('usuario@test.com'), findsOneWidget);
    });

    testWidgets('desmontar el widget sin controller explícito no lanza '
        'ninguna excepción (el controller interno se libera solo)',
        (tester) async {
      await tester.pumpWidget(envolver(
        const CustomInput(hintText: 'Correo', icon: Icons.email),
      ));

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('CustomInput — con controller explícito', () {
    testWidgets('escribir texto actualiza el controller pasado', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(envolver(
        CustomInput(hintText: 'Correo', icon: Icons.email, controller: controller),
      ));

      await tester.enterText(find.byType(TextField), 'x@y.com');

      expect(controller.text, 'x@y.com');
      controller.dispose();
    });

    testWidgets(
        'desmontar CustomInput NO libera un controller que vino de afuera '
        '— sigue usable después (si CustomInput lo hubiera liberado, esto '
        'lanzaría "used after being disposed")', (tester) async {
      final controller = TextEditingController(text: 'valor inicial');
      await tester.pumpWidget(envolver(
        CustomInput(hintText: 'Correo', icon: Icons.email, controller: controller),
      ));

      // Desmontar CustomInput reemplazando todo el árbol.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();

      // Si `CustomInput` hubiera liberado este controller (bug), leer/
      // escribir en él acá abajo lanzaría un FlutterError.
      expect(() => controller.text, returnsNormally);
      expect(controller.text, 'valor inicial');
      controller.text = 'sigue vivo';
      expect(controller.text, 'sigue vivo');

      // Este sí es nuestro (el test lo creó) — lo liberamos nosotros,
      // como corresponde a quien es dueño de un controller externo.
      controller.dispose();
    });

    testWidgets(
        'si `controller` cambia en un rebuild, el interno (si lo hubiera) '
        'se libera antes de adoptar el nuevo — no se pierde ni se filtra',
        (tester) async {
      final controlA = TextEditingController(text: 'A');
      final controlB = TextEditingController(text: 'B');

      await tester.pumpWidget(envolver(
        CustomInput(hintText: 'Correo', icon: Icons.email, controller: controlA),
      ));
      expect(find.text('A'), findsOneWidget);

      await tester.pumpWidget(envolver(
        CustomInput(hintText: 'Correo', icon: Icons.email, controller: controlB),
      ));
      await tester.pump();

      expect(find.text('B'), findsOneWidget);
      expect(find.text('A'), findsNothing);

      controlA.dispose();
      controlB.dispose();
    });
  });

  group('CustomInput — accesibilidad', () {
    testWidgets('el campo tiene un Semantics label persistente (hintText)',
        (tester) async {
      await tester.pumpWidget(envolver(
        const CustomInput(hintText: 'Correo electrónico', icon: Icons.email),
      ));

      expect(find.bySemanticsLabel('Correo electrónico'), findsOneWidget);
    });
  });
}