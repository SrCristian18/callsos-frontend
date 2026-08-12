import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:CallSos/core/app_routes.dart';
import 'package:CallSos/presentation/views/role_selection_view.dart';

void main() {
  Widget appDePrueba() {
    return MaterialApp(
      initialRoute: AppRoutes.roleSelection,
      routes: {
        AppRoutes.roleSelection: (_) => const RoleSelectionView(),
        AppRoutes.welcome: (context) {
          final rol = ModalRoute.of(context)!.settings.arguments as String;
          return Scaffold(body: Text('welcome:$rol'));
        },
      },
    );
  }

  testWidgets('renderiza el título y las dos tarjetas de rol', (tester) async {
    await tester.pumpWidget(appDePrueba());

    expect(find.text('¿Quién eres?'), findsOneWidget);
    expect(find.text('Denunciante'), findsOneWidget);
    expect(find.text('Agente de policía / CAI'), findsOneWidget);
  });

  testWidgets('tocar "Denunciante" navega a welcome con arguments="denunciante"', (tester) async {
    await tester.pumpWidget(appDePrueba());

    await tester.tap(find.text('Denunciante'));
    await tester.pumpAndSettle();

    expect(find.text('welcome:denunciante'), findsOneWidget);
  });

  testWidgets('tocar "Agente de policía / CAI" navega a welcome con arguments="policia"', (tester) async {
    await tester.pumpWidget(appDePrueba());

    await tester.tap(find.text('Agente de policía / CAI'));
    await tester.pumpAndSettle();

    expect(find.text('welcome:policia'), findsOneWidget);
  });
}
