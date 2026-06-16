import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Almacenamiento clave-valor seguro para datos sensibles (JWT, etc.).
///
/// F.0.4 — Gestión de sesión.
///
/// `FlutterSecureStorage` usa platform channels (Keychain en iOS,
/// EncryptedSharedPreferences en Android), que no están disponibles en
/// tests unitarios puros (`flutter_test` sin `TestWidgetsFlutterBinding`
/// con plugins). Esta interfaz permite que [SesionViewModel] reciba una
/// implementación en memoria durante los tests (ver
/// `sesion_viewmodel_test.dart`) y la implementación real
/// ([SecureStorageAdapter]) en la app.
abstract class ISecureStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Implementación real de [ISecureStorage] sobre `flutter_secure_storage`.
class SecureStorageAdapter implements ISecureStorage {
  final FlutterSecureStorage _storage;

  const SecureStorageAdapter([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}