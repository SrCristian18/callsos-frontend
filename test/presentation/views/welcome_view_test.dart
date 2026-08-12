import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:CallSos/core/app_routes.dart';
import 'package:CallSos/presentation/views/welcome_view.dart';

void main() {
  Widget appDePrueba(String rolInicial) {
    return MaterialApp(
      initialRoute: AppRoutes.welcome,
      onGenerateRoute: (settings) {
        if (settings.name == AppRoutes.welcome) {
          return MaterialPageRoute(
            settings: RouteSettings(arguments: rolInicial),
            builder: (_) => const WelcomeView(),
          );
        }
        return null;
      },
      routes: {
        AppRoutes.loginDenunciante: (_) => const Scaffold(body: Text('login_denunciante')),
        AppRoutes.loginPolicia: (_) => const Scaffold(body: Text('login_policia')),
        AppRoutes.registerDenunciante: (_) => const Scaffold(body: Text('register_denunciante')),
        AppRoutes.registerPolicia: (_) => const Scaffold(body: Text('register_policia')),
      },
    );
  }

  testWidgets('con role="denunciante" muestra el saludo en mayúsculas', (tester) async {
    await tester.pumpWidget(appDePrueba('denunciante'));

    expect(find.text('Hola, DENUNCIANTE'), findsOneWidget);
  });

  testWidgets('con role="denunciante", "Iniciar sesion" navega a loginDenunciante', (tester) async {
    await tester.pumpWidget(appDePrueba('denunciante'));

    await tester.tap(find.text('Iniciar sesion'));
    await tester.pumpAndSettle();

    expect(find.text('login_denunciante'), findsOneWidget);
  });

  testWidgets('con role="denunciante", "Registrarse" navega a registerDenunciante', (tester) async {
    await tester.pumpWidget(appDePrueba('denunciante'));

    await tester.tap(find.text('Registrarse'));
    await tester.pumpAndSettle();

    expect(find.text('register_denunciante'), findsOneWidget);
  });

  testWidgets('con role="policia", "Iniciar sesion" navega a loginPolicia', (tester) async {
    await tester.pumpWidget(appDePrueba('policia'));

    await tester.tap(find.text('Iniciar sesion'));
    await tester.pumpAndSettle();

    expect(find.text('login_policia'), findsOneWidget);
  });

  testWidgets('con role="policia", "Registrarse" navega a registerPolicia', (tester) async {
    await tester.pumpWidget(appDePrueba('policia'));

    await tester.tap(find.text('Registrarse'));
    await tester.pumpAndSettle();

    expect(find.text('register_policia'), findsOneWidget);
  });

  testWidgets('el botón de regreso llama Navigator.pop', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Navigator(
        onGenerateRoute: (_) => MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Builder(builder: (context) {
              return ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    settings: const RouteSettings(arguments: 'denunciante'),
                    builder: (_) => const WelcomeView(),
                  ),
                ),
                child: const Text('ir a welcome'),
              );
            }),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('ir a welcome'));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeView), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeView), findsNothing);
    expect(find.text('ir a welcome'), findsOneWidget);
  });
}
