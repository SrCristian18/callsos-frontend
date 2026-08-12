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
import 'package:CallSos/presentation/views/register_policia_view.dart';

/// Épica 5 (ruta técnica) — widget test de RegisterPoliciaView.
///
/// RECUPERADO: el commit 4eebb41 ("fix de tests de vistas") sobrescribió
/// este archivo por accidente con una copia de
/// register_denunciante_view_test.dart — quedó probando
/// RegisterDenuncianteView con navegación a homeDenunciante, dejando
/// RegisterPoliciaView (y SesionViewModel.registrarAgente) sin ningún
/// test. Este archivo restaura el contrato real: registro de agente vía
/// token de invitación, SIN campo de CAI (el CAI viene incluido en el
/// token — ver el comentario de diseño en register_policia_view.dart),
/// navegando a homeAgente.
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
    // FIX (ver login_view_test.dart): sin este await, isLoading queda en
    // true para siempre y RegisterPoliciaView nunca renderiza el botón
    // "Registrar" (solo el spinner) — el tap() falla con "Found 0 widgets".
    await sesion.restaurarSesion();
  });

  Widget appDePrueba() {
    return ChangeNotifierProvider<SesionViewModel>.value(
      value: sesion,
      child: MaterialApp(
        initialRoute: AppRoutes.registerPolicia,
        routes: {
          AppRoutes.registerPolicia: (_) => const RegisterPoliciaView(),
          AppRoutes.homeAgente: (_) => const Scaffold(body: Text('home_agente')),
        },
      ),
    );
  }

  Future<void> llenarFormulario(WidgetTester tester) async {
    final campos = find.byType(TextField);
    await tester.enterText(campos.at(0), 'token-invitacion-xyz'); // token
    await tester.enterText(campos.at(1), 'Pedro Nuevo'); // nombre
    await tester.enterText(campos.at(2), '3008888888'); // celular
    await tester.enterText(campos.at(3), 'pedro.nuevo'); // usuario
    await tester.enterText(campos.at(4), 'Password123'); // password
    await tester.enterText(campos.at(5), 'Password123'); // confirmar
  }

  // FIX (mismo hallazgo que en register_denunciante_view_test.dart): el
  // formulario no cabe en el viewport de test por defecto (800x600) —
  // tester.ensureVisible() hace scroll dentro del SingleChildScrollView
  // hasta que el botón quede en pantalla antes de tocarlo.
  Future<void> tocarRegistrar(WidgetTester tester) async {
    final boton = find.text('Registrar');
    await tester.ensureVisible(boton);
    await tester.pumpAndSettle();
    await tester.tap(boton);
  }

  testWidgets(
      'renderiza los 6 campos, incluyendo token de invitación, sin campo de CAI',
      (tester) async {
    await tester.pumpWidget(appDePrueba());

    expect(find.byType(TextField), findsNWidgets(6));
    // El texto explicativo menciona el CAI (viene del token), pero no debe
    // existir NINGÚN CustomInput con hint de CAI/estación — documentado en
    // el propio código como decisión de diseño: el agente nunca lo escribe.
    expect(find.textContaining('CAI'), findsOneWidget);
    expect(find.textContaining('Estación'), findsNothing);
  });

  testWidgets('con campos incompletos no llama a registrarAgente', (tester) async {
    await tester.pumpWidget(appDePrueba());

    await tocarRegistrar(tester);
    await tester.pumpAndSettle();

    verifyNever(() => authService.registrarAgente(
          token: any(named: 'token'),
          nombre: any(named: 'nombre'),
          telefono: any(named: 'telefono'),
          username: any(named: 'username'),
          password: any(named: 'password'),
          confirmarPassword: any(named: 'confirmarPassword'),
        ));
  });

  testWidgets('registro exitoso navega a homeAgente', (tester) async {
    when(() => authService.registrarAgente(
          token: 'token-invitacion-xyz',
          nombre: 'Pedro Nuevo',
          telefono: '3008888888',
          username: 'pedro.nuevo',
          password: 'Password123',
          confirmarPassword: 'Password123',
        )).thenAnswer((_) async => const AuthResult(
          token: 'jwt-agente', actorId: 'ag-002', rol: Rol.AGENTE,
        ));

    await tester.pumpWidget(appDePrueba());
    await llenarFormulario(tester);
    await tocarRegistrar(tester);
    await tester.pumpAndSettle();

    expect(find.text('home_agente'), findsOneWidget);
  });

  testWidgets('token de invitación inválido muestra el error de negocio', (tester) async {
    when(() => authService.registrarAgente(
          token: any(named: 'token'),
          nombre: any(named: 'nombre'),
          telefono: any(named: 'telefono'),
          username: any(named: 'username'),
          password: any(named: 'password'),
          confirmarPassword: any(named: 'confirmarPassword'),
        )).thenThrow(const ApiException(
          type: ApiExceptionType.businessRule,
          message: 'Token de invitación inválido o expirado.',
        ));

    await tester.pumpWidget(appDePrueba());
    await llenarFormulario(tester);
    await tocarRegistrar(tester);
    await tester.pumpAndSettle();

    expect(find.text('Token de invitación inválido o expirado.'), findsOneWidget);
  });
}