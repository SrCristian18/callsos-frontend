import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:CallSos/core/app_routes.dart';
import 'package:CallSos/data/models/auth_result.dart';
import 'package:CallSos/data/models/enums/rol.dart';
import 'package:CallSos/data/services/auth_service.dart';
import 'package:CallSos/data/services/secure_storage.dart';
import 'package:CallSos/data/services/preferencias_storage.dart';
import 'package:CallSos/presentation/viewmodels/sesion_viewmodel.dart';
import 'package:CallSos/presentation/viewmodels/theme_viewmodel.dart';
import 'package:CallSos/presentation/views/ajustes_view.dart';

/// EPIC-08 (Design System, auditoría UX/UI) — widget test de AjustesView.
///
/// Cubre el criterio de terminado propio de la épica ("cambio de tema
/// persiste entre sesiones") a nivel de cableado UI -> ThemeViewModel
/// (la persistencia en sí ya está probada exhaustivamente en
/// theme_viewmodel_test.dart — acá solo confirmamos que tocar una opción
/// llama [ThemeViewModel.cambiarTema] con el modo correcto), más los
/// datos de cuenta y el flujo de cerrar sesión.
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

class FakePreferenciasStorage implements IPreferenciasStorage {
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
  late ThemeViewModel temaVm;

  setUp(() async {
    authService = MockAuthService();
    sesion = SesionViewModel(authService: authService, storage: FakeSecureStorage());
    temaVm = ThemeViewModel(storage: FakePreferenciasStorage());

    when(() => authService.login(username: 'agt-001', password: '1234')).thenAnswer(
      (_) async => const AuthResult(
          token: 'jwt-agt', actorId: 'agt-001', rol: Rol.AGENTE, nombre: 'Pedro Agente'),
    );
    await sesion.login(username: 'agt-001', password: '1234');
  });

  Widget appDePrueba() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SesionViewModel>.value(value: sesion),
        ChangeNotifierProvider<ThemeViewModel>.value(value: temaVm),
      ],
      child: MaterialApp(
        home: const AjustesView(),
        routes: {
          AppRoutes.roleSelection: (_) => const Scaffold(body: Text('role_selection')),
        },
      ),
    );
  }

  group('Sección Cuenta', () {
    testWidgets('muestra el nombre y el rol del usuario autenticado', (tester) async {
      await tester.pumpWidget(appDePrueba());

      expect(find.text('Pedro Agente'), findsOneWidget);
      expect(find.text('Agente de Policía'), findsOneWidget);
    });
  });

  group('Sección Tema', () {
    testWidgets('muestra las 3 opciones y marca ThemeMode.system por defecto',
        (tester) async {
      await tester.pumpWidget(appDePrueba());

      expect(find.text('Igual que el sistema'), findsOneWidget);
      expect(find.text('Claro'), findsOneWidget);
      expect(find.text('Oscuro'), findsOneWidget);

      // El valor seleccionado vive en el RadioGroup ancestro (API
      // vigente desde Flutter 3.32), no en cada RadioListTile.
      final grupo = tester.widget<RadioGroup<ThemeMode>>(
        find.byType(RadioGroup<ThemeMode>),
      );
      expect(grupo.groupValue, ThemeMode.system);
    });

    testWidgets('tocar "Oscuro" llama a ThemeViewModel.cambiarTema(ThemeMode.dark) '
        'y la UI reacciona al nuevo estado', (tester) async {
      await tester.pumpWidget(appDePrueba());

      await tester.tap(find.text('Oscuro'));
      await tester.pumpAndSettle();

      expect(temaVm.themeMode, ThemeMode.dark);

      final grupo = tester.widget<RadioGroup<ThemeMode>>(
        find.byType(RadioGroup<ThemeMode>),
      );
      expect(grupo.groupValue, ThemeMode.dark);
    });

    testWidgets('el tema elegido se persiste vía el storage del ThemeViewModel '
        '(mecanismo de EPIC-02, no reimplementado acá)', (tester) async {
      final storage = FakePreferenciasStorage();
      temaVm = ThemeViewModel(storage: storage);

      await tester.pumpWidget(appDePrueba());
      await tester.tap(find.text('Claro'));
      await tester.pumpAndSettle();

      expect(await storage.read('theme_mode'), 'light');
    });
  });

  group('Cerrar sesión', () {
    testWidgets('pide confirmación antes de cerrar sesión', (tester) async {
      await tester.pumpWidget(appDePrueba());

      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();

      expect(find.text('¿Cerrar sesión?'), findsOneWidget);
      expect(sesion.isAuthenticated, isTrue);
    });

    testWidgets('cancelar el diálogo NO cierra la sesión', (tester) async {
      await tester.pumpWidget(appDePrueba());

      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(sesion.isAuthenticated, isTrue);
      expect(find.text('role_selection'), findsNothing);
    });

    testWidgets('confirmar cierra la sesión y navega a roleSelection, '
        'limpiando el stack (no se puede volver atrás)', (tester) async {
      await tester.pumpWidget(appDePrueba());

      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      // El diálogo tiene su propio botón "Cerrar sesión" (TextButton) —
      // el ListTile de origen sigue en el árbol detrás del diálogo, así
      // que find.text('Cerrar sesión') a esta altura es ambiguo (2
      // matches). El botón de confirmar es el único TextButton con ese
      // texto, así que ese finder sí es inequívoco.
      await tester.tap(find.widgetWithText(TextButton, 'Cerrar sesión'));
      await tester.pumpAndSettle();

      expect(sesion.isAuthenticated, isFalse);
      expect(find.text('role_selection'), findsOneWidget);
    });
  });

  group('Versión de la app', () {
    testWidgets('muestra la versión de la app', (tester) async {
      await tester.pumpWidget(appDePrueba());

      expect(find.textContaining('CallSOS · v'), findsOneWidget);
    });
  });
}