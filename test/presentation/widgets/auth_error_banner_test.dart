import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:CallSos/presentation/widgets/auth_error_banner.dart';

void main() {
  Widget appDePrueba(String mensaje) {
    return MaterialApp(
      home: Scaffold(body: AuthErrorBanner(mensaje: mensaje)),
    );
  }

  testWidgets('muestra el mensaje recibido', (tester) async {
    await tester.pumpWidget(appDePrueba('Usuario o contraseña incorrectos.'));

    expect(find.text('Usuario o contraseña incorrectos.'), findsOneWidget);
  });

  testWidgets('muestra el ícono de error', (tester) async {
    await tester.pumpWidget(appDePrueba('Error de red.'));

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('ocupa el ancho completo disponible', (tester) async {
    await tester.pumpWidget(appDePrueba('Error.'));

    final container = tester.widget<Container>(find.byType(Container).first);
    expect(container.constraints?.maxWidth, double.infinity);
  });
}