import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:CallSos/presentation/views/forgot_password_view.dart';

/// EPIC-13 (Design System, auditoría UX/UI) — antes, el botón "Enviar"
/// no tenía NINGUNA lógica conectada (`onPressed: () {}`) y tocarlo no
/// daba ningún feedback. Ahora, mientras no exista el endpoint de
/// recuperación de contraseña, el botón comunica esa limitación con
/// honestidad (mismo criterio que EPIC-12 aplicó al tab "Delegados" de
/// Comando) en vez de quedarse en silencio.
void main() {
  Widget appDePrueba() {
    return MaterialApp(
      home: Navigator(
        onGenerateRoute: (_) => MaterialPageRoute(
          builder: (_) => const ForgotPasswordView(),
        ),
      ),
    );
  }

  testWidgets('renderiza título, campo de correo y botón Enviar', (tester) async {
    await tester.pumpWidget(appDePrueba());

    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Enviar'), findsOneWidget);
  });

  testWidgets(
      'tocar "Enviar" muestra un aviso honesto de que la función no '
      'está disponible (sin lanzar excepciones)', (tester) async {
    await tester.pumpWidget(appDePrueba());

    await tester.tap(find.text('Enviar'));
    await tester.pump(); // el SnackBar anima su entrada

    expect(tester.takeException(), isNull);
    expect(
      find.textContaining('todavía no está disponible'),
      findsOneWidget,
    );
  });

  testWidgets('el botón de regreso está presente', (tester) async {
    await tester.pumpWidget(appDePrueba());

    expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
  });
}