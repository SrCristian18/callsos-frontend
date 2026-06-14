import 'package:flutter_test/flutter_test.dart';

/// Smoke test placeholder.
///
/// Este archivo venía vacío (0 bytes) en el proyecto original, sin función
/// `main()` — lo cual hace fallar `flutter test` para TODO el proyecto
/// (no solo para los tests nuevos de F.0.2), ya que `flutter test` intenta
/// cargar cada archivo bajo `test/` como un suite y requiere un `main()`.
///
/// Se reemplaza por un smoke test mínimo para desbloquear la ejecución de
/// `flutter test`. La suite real de widgets (smoke test de `MyApp`,
/// navegación, etc.) se construye en F.7 junto con los tests de
/// ViewModels/servicios, una vez existan las pantallas reales (F.1-F.4).
void main() {
  test('placeholder — flutter test puede ejecutarse', () {
    expect(1 + 1, 2);
  });
}