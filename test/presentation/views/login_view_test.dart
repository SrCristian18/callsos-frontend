import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:CallSos/core/app_routes.dart';
import 'package:CallSos/data/models/auth_result.dart';
import 'package:CallSos/data/models/enums/rol.dart';
import 'package:CallSos/data/services/api_exception.dart';
import 'package:CallSos/data/services/auth_service.dart';
import 'package:CallSos/data/services/secure_storage.dart';
import 'package:CallSos/presentation/viewmodels/sesion_viewmodel.dart';
import 'package:CallSos/presentation/views/login_view.dart';

class MockAuthService extends Mock implements IAuthService {}

class FakeSecureStorage implements ISecureStorage {
  final Map<String, String> _datos = {};
  @override
  Future<String?> read(String key) async => _datos[key];
  @override
  Future<void> write(String key, String value) async => _datos[key] = value;
  @override
  Future<void> delete(String key) async => _datos.remove(key);
}

void main() {
  late MockAuthService authService;
  late SesionViewModel sesion;

  setUp(() async {
    authService = MockAuthService();
    sesion = SesionViewModel(authService: authService, storage: FakeSecureStorage());
    // FIX: SesionViewModel arranca con isLoading == true hasta que
    // restaurarSesion() termina (así lo hace AppProviders en la app real
    // antes de mostrar cualquier vista). Sin este await, isLoading queda
    // en true para siempre y LoginView solo renderiza el
    // CircularProgressIndicator — el botón "Iniciar sesión" nunca existe
    // y todos los find.text/tap sobre él fallan con "Found 0 widgets".
    await sesion.restaurarSesion();
  });

  Widget appDePrueba() {
    return ChangeNotifierProvider<SesionViewModel>.value(
      value: sesion,
      child: MaterialApp(
        initialRoute: AppRoutes.loginDenunciante,
        routes: {
          AppRoutes.loginDenunciante: (_) => const LoginView(),
          AppRoutes.homeDenunciante: (_) => const Scaffold(body: Text('home_denunciante')),
          AppRoutes.forgotPassword: (_) => const Scaffold(body: Text('forgot_password')),
        },
      ),
    );
  }

  testWidgets('renderiza los campos de usuario y contraseña', (tester) async {
    await tester.pumpWidget(appDePrueba());

    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('con campos vacíos, no llama a sesion.login', (tester) async {
    await tester.pumpWidget(appDePrueba());

    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    verifyNever(() => authService.login(username: any(named: 'username'), password: any(named: 'password')));
  });

  testWidgets('login exitoso navega a homeDenunciante', (tester) async {
    when(() => authService.login(username: 'juan', password: '1234')).thenAnswer(
      (_) async => const AuthResult(token: 'jwt-xyz', actorId: 'den-001', rol: Rol.DENUNCIANTE),
    );

    await tester.pumpWidget(appDePrueba());
    await tester.enterText(find.byType(TextField).at(0), 'juan');
    await tester.enterText(find.byType(TextField).at(1), '1234');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('home_denunciante'), findsOneWidget);
  });

  testWidgets('login fallido muestra el mensaje de error y no navega', (tester) async {
    when(() => authService.login(username: 'juan', password: 'mala')).thenThrow(
      const ApiException(type: ApiExceptionType.unauthorized, message: 'Usuario o contraseña incorrectos.'),
    );

    await tester.pumpWidget(appDePrueba());
    await tester.enterText(find.byType(TextField).at(0), 'juan');
    await tester.enterText(find.byType(TextField).at(1), 'mala');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Usuario o contraseña incorrectos.'), findsOneWidget);
    expect(find.text('home_denunciante'), findsNothing);
  });

  testWidgets('mientras isLoading, muestra spinner en vez del botón', (tester) async {
    when(() => authService.login(username: 'juan', password: '1234')).thenAnswer(
      (_) => Future.delayed(
        const Duration(milliseconds: 200),
        () => const AuthResult(token: 't', actorId: 'den-001', rol: Rol.DENUNCIANTE),
      ),
    );

    await tester.pumpWidget(appDePrueba());
    await tester.enterText(find.byType(TextField).at(0), 'juan');
    await tester.enterText(find.byType(TextField).at(1), '1234');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pump(); // un frame — la llamada async todavía no resuelve

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsNothing);

    await tester.pumpAndSettle();
  });

  testWidgets('"¿Olvidaste tu contraseña?" navega a forgotPassword', (tester) async {
    await tester.pumpWidget(appDePrueba());

    await tester.tap(find.text('¿Olvidaste tu contraseña?'));
    await tester.pumpAndSettle();

    expect(find.text('forgot_password'), findsOneWidget);
  });
}