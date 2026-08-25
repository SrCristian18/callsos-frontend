import 'package:flutter/material.dart';

import '../../data/services/preferencias_storage.dart';

/// Gestiona el [ThemeMode] activo de la app (claro/oscuro/sistema) y lo
/// persiste localmente entre sesiones.
///
/// EPIC-02 (Design System, auditoría UX/UI) — resuelve el hallazgo #4
/// (sin dark mode ni sistema de temas). Por defecto usa [ThemeMode.system]
/// (sigue el tema del sistema operativo automáticamente) — es la primera
/// vez que la app respeta esa preferencia; antes `main.dart` tenía un
/// único `ThemeData` fijo.
///
/// Alcance de ESTA épica: el mecanismo (persistencia + reactividad +
/// modo `system` automático). La UI para elegirlo manualmente
/// (claro/oscuro/sistema, con radio buttons o similar) es EPIC-08
/// (`AjustesView`) — hasta entonces, [themeMode] solo puede llegar a
/// `light`/`dark` si se restaura un valor ya guardado de una sesión
/// anterior (por ejemplo, tras EPIC-08 exista y el usuario ya haya
/// elegido uno) o si se llama [cambiarTema] programáticamente.
///
/// Uso (ver `AppProviders`):
/// ```dart
/// ChangeNotifierProvider<ThemeViewModel>(
///   create: (_) {
///     final vm = ThemeViewModel(storage: SharedPreferencesAdapter());
///     vm.cargarTemaGuardado(); // fire-and-forget, mismo patrón que
///                              // SesionViewModel.restaurarSesion()
///     return vm;
///   },
/// ),
/// ```
class ThemeViewModel extends ChangeNotifier {
  static const String _claveStorage = 'theme_mode';

  final IPreferenciasStorage _storage;

  ThemeViewModel({required IPreferenciasStorage storage}) : _storage = storage;

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  /// Restaura el tema guardado en una sesión anterior, si existe.
  ///
  /// Si no hay nada persistido (primera vez que se abre la app, o el
  /// valor guardado es inválido/corrupto), se queda en
  /// [ThemeMode.system] — nunca lanza, nunca deja el estado a medias.
  Future<void> cargarTemaGuardado() async {
    final guardado = await _storage.read(_claveStorage);
    if (guardado == null) return; // sin preferencia guardada -> system

    final modo = _parsear(guardado);
    if (modo == null) return; // valor corrupto/desconocido -> system

    _themeMode = modo;
    notifyListeners();
  }

  /// Cambia el tema activo y lo persiste para la próxima sesión.
  Future<void> cambiarTema(ThemeMode modo) async {
    if (modo == _themeMode) return; // no-op, evita notify innecesario

    _themeMode = modo;
    notifyListeners();

    await _storage.write(_claveStorage, _serializar(modo));
  }

  static String _serializar(ThemeMode modo) => switch (modo) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };

  static ThemeMode? _parsear(String valor) => switch (valor) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => null,
      };
}