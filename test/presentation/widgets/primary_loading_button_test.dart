import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:CallSos/presentation/widgets/primary_loading_button.dart';

void main() {
  Widget appDePrueba({
    required bool isLoading,
    VoidCallback? onPressed,
    String label = 'Continuar',
  }) {
    return MaterialApp(
      home: Scaffold(
        body: PrimaryLoadingButton(
          label: label,
          isLoading: isLoading,
          onPressed: onPressed ?? () {},
        ),
      ),
    );
  }

  testWidgets('sin cargar, muestra el texto y el botón está habilitado',
      (tester) async {
    var tocado = false;
    await tester.pumpWidget(
        appDePrueba(isLoading: false, onPressed: () => tocado = true));

    expect(find.text('Continuar'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.byType(ElevatedButton));
    expect(tocado, isTrue);
  });

  testWidgets(
      'cargando, reemplaza el texto por un spinner chico y deshabilita '
      'el botón (mismo tamaño, sin saltos de layout)', (tester) async {
    var tocado = false;
    await tester.pumpWidget(
        appDePrueba(isLoading: true, onPressed: () => tocado = true));

    expect(find.text('Continuar'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final boton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(boton.onPressed, isNull);

    // El botón sigue ocupando el mismo tamaño (ancho completo, 50 de
    // alto) tanto cargando como no — el fix central de EPIC-13 para
    // este widget: nada de saltos de layout.
    final size = tester.getSize(find.byType(SizedBox).first);
    expect(size.height, 50);

    await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
    expect(tocado, isFalse);
  });

  testWidgets('acepta colores custom (ej. AppColors.negroTexto en '
      'LoginPoliciaView)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrimaryLoadingButton(
            label: 'Iniciar sesión',
            isLoading: false,
            backgroundColor: Colors.black,
            onPressed: () {},
          ),
        ),
      ),
    );

    final boton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    final bg = boton.style?.backgroundColor?.resolve({});
    expect(bg, Colors.black);
  });
}