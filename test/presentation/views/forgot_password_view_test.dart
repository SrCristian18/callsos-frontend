import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:CallSos/presentation/views/forgot_password_view.dart';

/// NOTA — gap detectado (documentado a propósito, no simulado como si
/// funcionara): el botón "Enviar" no tiene NINGUNA lógica conectada (ver
/// el comentario "Aquí iría la lógica para enviar el correo" en el propio
/// archivo). Este test verifica el estado REAL de la vista — que el botón
/// existe y es tocable sin crashear — no que "envíe un correo", porque
/// eso no está implementado todavía.
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

  testWidgets('tocar "Enviar" no lanza ninguna excepción (no-op, funcionalidad pendiente)', (tester) async {
    await tester.pumpWidget(appDePrueba());

    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('el botón de regreso está presente', (tester) async {
    await tester.pumpWidget(appDePrueba());

    expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
  });
}
