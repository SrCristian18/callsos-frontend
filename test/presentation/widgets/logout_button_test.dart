import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:CallSos/core/app_routes.dart';
import 'package:CallSos/data/models/auth_result.dart';
import 'package:CallSos/data/models/enums/rol.dart';
import 'package:CallSos/data/services/auth_service.dart';
import 'package:CallSos/data/services/secure_storage.dart';
import 'package:CallSos/presentation/viewmodels/sesion_viewmodel.dart';
import 'package:CallSos/presentation/widgets/logout_button.dart';

/// Cubre [LogoutButton] de forma aislada — EPIC-04 (auditoría UX/UI),
/// fix del hallazgo #2 (CRÍTICO). Los tests de las 4 Home views ya
/// verifican la integración real (`home_denunciante_view_test.dart`,
/// etc.); este archivo cubre el widget en sí, independiente de en qué
/// Home esté montado.
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

    when(() => authService.login(username: 'den-001', password: '1234')).thenAnswer(
      (_) async => const AuthResult(
          token: 'jwt-den', actorId: 'den-001', rol: Rol.DENUNCIANTE, nombre: 'Ana'),
    );
    await sesion.login(username: 'den-001', password: '1234');
  });

  Widget appDePrueba() {
    return ChangeNotifierProvider<SesionViewModel>.value(
      value: sesion,
      child: MaterialApp(
        home: const Scaffold(
          appBar: null,
          body: Center(child: LogoutButton()),
        ),
        routes: {
          AppRoutes.roleSelection: (_) => const Scaffold(body: Text('role_selection')),
        },
      ),
    );
  }

  group('LogoutButton — render', () {
    testWidgets('muestra el ícono de logout con tooltip "Cerrar sesión"',
        (tester) async {
      await tester.pumpWidget(appDePrueba());

      expect(find.byIcon(Icons.logout), findsOneWidget);
      expect(find.byTooltip('Cerrar sesión'), findsOneWidget);
    });
  });

  group('LogoutButton — fix hallazgo #2: pide confirmación', () {
    testWidgets('tocar el ícono NO cierra la sesión de inmediato — abre confirmación primero',
        (tester) async {
      await tester.pumpWidget(appDePrueba());

      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();

      // Antes del fix, este único tap ya deslogueaba. Ahora la sesión
      // sigue activa hasta que se confirme explícitamente.
      expect(sesion.isAuthenticated, isTrue);
      expect(find.text('¿Cerrar sesión?'), findsOneWidget);
    });

    testWidgets('confirmar cierra la sesión y navega a roleSelection',
        (tester) async {
      await tester.pumpWidget(appDePrueba());

      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();

      expect(sesion.isAuthenticated, isFalse);
      expect(find.text('role_selection'), findsOneWidget);
    });

    testWidgets('cancelar NO cierra la sesión ni navega', (tester) async {
      await tester.pumpWidget(appDePrueba());

      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(sesion.isAuthenticated, isTrue);
      expect(find.text('role_selection'), findsNothing);
      // El diálogo se cerró (no quedó colgado tras cancelar).
      expect(find.text('¿Cerrar sesión?'), findsNothing);
    });

    testWidgets(
        'tocar afuera del diálogo (barrierDismissible=false) NO cierra la sesión',
        (tester) async {
      await tester.pumpWidget(appDePrueba());

      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      // El diálogo sigue abierto — ConfirmationDialog.show() se llama
      // con barrierDismissible: false por defecto (isDangerous: true).
      expect(find.text('¿Cerrar sesión?'), findsOneWidget);
      expect(sesion.isAuthenticated, isTrue);
    });

    testWidgets('el diálogo de confirmación usa estilo "peligroso" (isDangerous)',
        (tester) async {
      await tester.pumpWidget(appDePrueba());

      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();

      final boton = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Cerrar sesión'),
          matching: find.byType(TextButton),
        ),
      );
      final color = boton.style!.foregroundColor!.resolve({});
      expect(color, const Color(0xFFD32F2F)); // AppColors.error
    });
  });

  group('LogoutButton — color de ícono configurable', () {
    testWidgets('iconColor por defecto es blanco (para AppBars de color)',
        (tester) async {
      await tester.pumpWidget(appDePrueba());

      final icono = tester.widget<Icon>(find.byIcon(Icons.logout));
      expect(icono.color, Colors.white);
    });

    testWidgets('acepta un iconColor personalizado', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<SesionViewModel>.value(
          value: sesion,
          child: MaterialApp(
            home: const Scaffold(
              body: Center(child: LogoutButton(iconColor: Colors.black)),
            ),
          ),
        ),
      );

      final icono = tester.widget<Icon>(find.byIcon(Icons.logout));
      expect(icono.color, Colors.black);
    });
  });
}