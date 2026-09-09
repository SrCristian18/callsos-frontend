import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:CallSos/core/app_routes.dart';
import 'package:CallSos/data/services/api_exception.dart';
import 'package:CallSos/data/services/auth_service.dart';
import 'package:CallSos/data/services/secure_storage.dart';
import 'package:CallSos/presentation/viewmodels/sesion_viewmodel.dart';
import 'package:CallSos/presentation/views/forgot_password_view.dart';

/// FIX (auditoría AUD-1): este archivo probaba el comportamiento ANTERIOR
/// de [ForgotPasswordView], cuando el botón "Enviar" no llamaba a ningún
/// endpoint (el backend no lo tenía) y solo mostraba una advertencia
/// ("todavía no está disponible"). Eso dejó de ser cierto — el backend ya
/// expone `POST /auth/recuperar-password` completo y la vista ahora lo
/// consume de verdad — así que ese comportamiento ya no existe y este
/// archivo se reescribe por completo para probar el flujo real, con el
/// mismo patrón de mocks que `register_denunciante_view_test.dart`
/// (`MockAuthService` + `FakeSecureStorage` + `SesionViewModel` real
/// inyectado vía `ChangeNotifierProvider.value`).
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
    // FIX: ver login_view_test.dart / register_denunciante_view_test.dart
    // — sin este await, isLoading queda en true para siempre.
    await sesion.restaurarSesion();
  });

  Widget appDePrueba() {
    return ChangeNotifierProvider<SesionViewModel>.value(
      value: sesion,
      child: MaterialApp(
        initialRoute: AppRoutes.forgotPassword,
        routes: {
          AppRoutes.forgotPassword: (_) => const ForgotPasswordView(),
          // Placeholder — solo interesa confirmar que la navegación
          // ocurrió tras un envío exitoso, no probar ResetPasswordView
          // acá (tiene su propio archivo de test).
          AppRoutes.resetPassword: (_) => const Scaffold(
                body: Text('reset_password_screen'),
              ),
        },
      ),
    );
  }

  testWidgets('renderiza título, campo de correo y botón Enviar', (tester) async {
    await tester.pumpWidget(appDePrueba());

    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Enviar'), findsOneWidget);
  });

  testWidgets('el botón de regreso está presente', (tester) async {
    await tester.pumpWidget(appDePrueba());

    expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
  });

  testWidgets('con el correo vacío no llama a recuperarPassword', (tester) async {
    await tester.pumpWidget(appDePrueba());

    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();

    verifyNever(() => authService.recuperarPassword(correo: any(named: 'correo')));
  });

  testWidgets(
      'envío exitoso navega a ResetPasswordView con el correo como argumento',
      (tester) async {
    when(() => authService.recuperarPassword(correo: 'ana@test.com'))
        .thenAnswer((_) async =>
            'Si el correo existe, recibirás un código de verificación.');

    await tester.pumpWidget(appDePrueba());
    await tester.enterText(find.byType(TextField), 'ana@test.com');
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();

    expect(find.text('reset_password_screen'), findsOneWidget);
  });

  testWidgets('error de red muestra el mensaje sin navegar', (tester) async {
    when(() => authService.recuperarPassword(correo: any(named: 'correo')))
        .thenThrow(const ApiException(
      type: ApiExceptionType.noConnection,
      message: 'No se pudo conectar con el servidor.',
    ));

    await tester.pumpWidget(appDePrueba());
    await tester.enterText(find.byType(TextField), 'ana@test.com');
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo conectar con el servidor.'), findsOneWidget);
    // No debe haber navegado — seguimos en ForgotPasswordView.
    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
    expect(find.text('reset_password_screen'), findsNothing);
  });
}