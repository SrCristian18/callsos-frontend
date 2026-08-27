import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:CallSos/data/services/preferencias_storage.dart';
import 'package:CallSos/presentation/viewmodels/theme_viewmodel.dart';

/// Almacenamiento en memoria para tests (mismo patrón que
/// `FakeSecureStorage` en `sesion_viewmodel_test.dart`).
class FakePreferenciasStorage implements IPreferenciasStorage {
  final Map<String, String> _datos = {};

  @override
  Future<String?> read(String key) async => _datos[key];

  @override
  Future<void> write(String key, String value) async => _datos[key] = value;

  @override
  Future<void> delete(String key) async => _datos.remove(key);

  bool get estaVacio => _datos.isEmpty;
}

void main() {
  late FakePreferenciasStorage storage;
  late ThemeViewModel vm;

  setUp(() {
    storage = FakePreferenciasStorage();
    vm = ThemeViewModel(storage: storage);
  });

  group('estado inicial', () {
    test('por defecto es ThemeMode.system, sin tocar el storage', () {
      expect(vm.themeMode, ThemeMode.system);
      expect(storage.estaVacio, isTrue);
    });
  });

  group('cargarTemaGuardado', () {
    test('sin nada persistido, se queda en system', () async {
      await vm.cargarTemaGuardado();
      expect(vm.themeMode, ThemeMode.system);
    });

    test('restaura "dark" guardado en una sesión anterior', () async {
      await storage.write('theme_mode', 'dark');

      await vm.cargarTemaGuardado();

      expect(vm.themeMode, ThemeMode.dark);
    });

    test('restaura "light" guardado en una sesión anterior', () async {
      await storage.write('theme_mode', 'light');

      await vm.cargarTemaGuardado();

      expect(vm.themeMode, ThemeMode.light);
    });

    test('valor corrupto/desconocido en storage no lanza, se queda en system',
        () async {
      await storage.write('theme_mode', 'valor-invalido-xyz');

      await vm.cargarTemaGuardado();

      expect(vm.themeMode, ThemeMode.system);
    });

    test('notifica a los listeners cuando restaura un valor distinto al default',
        () async {
      await storage.write('theme_mode', 'dark');
      var notificado = false;
      vm.addListener(() => notificado = true);

      await vm.cargarTemaGuardado();

      expect(notificado, isTrue);
    });
  });

  group('cambiarTema', () {
    test('actualiza themeMode y persiste el nuevo valor', () async {
      await vm.cambiarTema(ThemeMode.dark);

      expect(vm.themeMode, ThemeMode.dark);
      expect(await storage.read('theme_mode'), 'dark');
    });

    test('persiste "light" y "system" con las claves esperadas', () async {
      await vm.cambiarTema(ThemeMode.light);
      expect(await storage.read('theme_mode'), 'light');

      await vm.cambiarTema(ThemeMode.system);
      expect(await storage.read('theme_mode'), 'system');
    });

    test('notifica a los listeners al cambiar', () async {
      var notificaciones = 0;
      vm.addListener(() => notificaciones++);

      await vm.cambiarTema(ThemeMode.dark);

      expect(notificaciones, 1);
    });

    test('llamar con el mismo modo actual no notifica ni escribe en storage '
        '(no-op)', () async {
      // ThemeMode.system ya es el default — no hay cambio real.
      var notificaciones = 0;
      vm.addListener(() => notificaciones++);

      await vm.cambiarTema(ThemeMode.system);

      expect(notificaciones, 0);
      expect(storage.estaVacio, isTrue);
    });

    test('cambios sucesivos persisten siempre el último valor', () async {
      await vm.cambiarTema(ThemeMode.dark);
      await vm.cambiarTema(ThemeMode.light);

      expect(vm.themeMode, ThemeMode.light);
      expect(await storage.read('theme_mode'), 'light');
    });
  });
}