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
import 'package:CallSos/presentation/views/register_denunciante_view.dart';

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
        initialRoute: AppRoutes.registerDenunciante,
        routes: {
          AppRoutes.registerDenunciante: (_) => const RegisterDenuncianteView(),
          AppRoutes.homeDenunciante: (_) => const Scaffold(body: Text('home_denunciante')),
        },
      ),
    );
  }

  Future<void> llenarFormulario(WidgetTester tester) async {
    final campos = find.byType(TextField);
    await tester.enterText(campos.at(0), 'Ana');
    await tester.enterText(campos.at(1), 'Nueva');
    await tester.enterText(campos.at(2), '1009999999');
    await tester.enterText(campos.at(3), '3009999999');
    await tester.enterText(campos.at(4), 'Password123');
    await tester.enterText(campos.at(5), 'Password123');
  }

  testWidgets('renderiza los 6 campos del formulario', (tester) async {
    await tester.pumpWidget(appDePrueba());
    expect(find.byType(TextField), findsNWidgets(6));
  });

  testWidgets('con campos incompletos no llama a registrarDenunciante', (tester) async {
    await tester.pumpWidget(appDePrueba());

    await tester.enterText(find.byType(TextField).at(0), 'Ana'); // solo el primero
    await tester.tap(find.text('Registrar'));
    await tester.pumpAndSettle();

    verifyNever(() => authService.registrarDenunciante(
          nombre: any(named: 'nombre'),
          apellido: any(named: 'apellido'),
          documento: any(named: 'documento'),
          telefono: any(named: 'telefono'),
          password: any(named: 'password'),
          confirmarPassword: any(named: 'confirmarPassword'),
        ));
  });

  testWidgets('registro exitoso navega a homeDenunciante', (tester) async {
    when(() => authService.registrarDenunciante(
          nombre: 'Ana',
          apellido: 'Nueva',
          documento: '1009999999',
          telefono: '3009999999',
          password: 'Password123',
          confirmarPassword: 'Password123',
        )).thenAnswer((_) async => const AuthResult(
          token: 'jwt-xyz', actorId: 'den-002', rol: Rol.DENUNCIANTE, nombre: 'Ana Nueva',
        ));

    await tester.pumpWidget(appDePrueba());
    await llenarFormulario(tester);
    await tester.tap(find.text('Registrar'));
    await tester.pumpAndSettle();

    expect(find.text('home_denunciante'), findsOneWidget);
  });

  testWidgets('registro con documento duplicado muestra el error de negocio', (tester) async {
    when(() => authService.registrarDenunciante(
          nombre: any(named: 'nombre'),
          apellido: any(named: 'apellido'),
          documento: any(named: 'documento'),
          telefono: any(named: 'telefono'),
          password: any(named: 'password'),
          confirmarPassword: any(named: 'confirmarPassword'),
        )).thenThrow(const ApiException(
          type: ApiExceptionType.businessRule,
          message: 'El documento ya está registrado.',
        ));

    await tester.pumpWidget(appDePrueba());
    await llenarFormulario(tester);
    await tester.tap(find.text('Registrar'));
    await tester.pumpAndSettle();

    expect(find.text('El documento ya está registrado.'), findsOneWidget);
  });
}
