import 'package:shared_preferences/shared_preferences.dart';

/// Almacenamiento clave-valor LOCAL para preferencias de UI no sensibles
/// (tema, idioma, etc. — nunca JWT ni datos de sesión, para eso existe
/// [ISecureStorage]).
///
/// EPIC-02 (Design System, auditoría UX/UI) — mismo propósito y misma
/// forma que [ISecureStorage]: permite que [ThemeViewModel] reciba una
/// implementación en memoria durante los tests (ver
/// `theme_viewmodel_test.dart`) y la real ([SharedPreferencesAdapter])
/// en la app, sin acoplar el ViewModel al plugin de Flutter.
abstract class IPreferenciasStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Implementación real de [IPreferenciasStorage] sobre `shared_preferences`.
class SharedPreferencesAdapter implements IPreferenciasStorage {
  @override
  Future<String?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  @override
  Future<void> write(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  @override
  Future<void> delete(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}