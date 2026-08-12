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
import 'package:CallSos/presentation/views/login_policia_view.dart';

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

  setUp(() {
    authService = MockAuthService();
    sesion = SesionViewModel(authService: authService, storage: FakeSecureStorage());
  });

  Widget appDePrueba() {
    return ChangeNotifierProvider<SesionViewModel>.value(
      value: sesion,
      child: MaterialApp(
        initialRoute: AppRoutes.loginPolicia,
        routes: {
          AppRoutes.loginPolicia: (_) => const LoginPoliciaView(),
          AppRoutes.homeAgente: (_) => const Scaffold(body: Text('home_agente')),
          AppRoutes.homeCai: (_) => const Scaffold(body: Text('home_cai')),
          AppRoutes.homeComando: (_) => const Scaffold(body: Text('home_comando')),
          '/forgot_password': (_) => const Scaffold(body: Text('forgot_password')),
        },
      ),
    );
  }

  Future<void> loguearComo(WidgetTester tester, Rol rol) async {
    when(() => authService.login(username: 'pedro', password: '1234')).thenAnswer(
      (_) async => AuthResult(token: 'jwt', actorId: 'actor-001', rol: rol),
    );

    await tester.pumpWidget(appDePrueba());
    await tester.enterText(find.byType(TextField).at(0), 'pedro');
    await tester.enterText(find.byType(TextField).at(1), '1234');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
  }

  testWidgets('login como AGENTE navega a homeAgente', (tester) async {
    await loguearComo(tester, Rol.AGENTE);
    expect(find.text('home_agente'), findsOneWidget);
  });

  testWidgets('login como OPERADOR_CAI navega a homeCai', (tester) async {
    await loguearComo(tester, Rol.OPERADOR_CAI);
    expect(find.text('home_cai'), findsOneWidget);
  });

  testWidgets('login como COMANDO navega a homeComando', (tester) async {
    await loguearComo(tester, Rol.COMANDO);
    expect(find.text('home_comando'), findsOneWidget);
  });

  testWidgets('login fallido muestra el error y no navega', (tester) async {
    when(() => authService.login(username: 'pedro', password: 'mala')).thenThrow(
      const ApiException(type: ApiExceptionType.unauthorized, message: 'Usuario o contraseña incorrectos.'),
    );

    await tester.pumpWidget(appDePrueba());
    await tester.enterText(find.byType(TextField).at(0), 'pedro');
    await tester.enterText(find.byType(TextField).at(1), 'mala');
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Usuario o contraseña incorrectos.'), findsOneWidget);
  });

  testWidgets('con campos vacíos no llama a login', (tester) async {
    await tester.pumpWidget(appDePrueba());

    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    verifyNever(() => authService.login(username: any(named: 'username'), password: any(named: 'password')));
  });
}
