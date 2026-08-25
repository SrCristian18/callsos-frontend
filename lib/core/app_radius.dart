import 'package:flutter/material.dart';

/// Escala de radios de borde — EPIC-01 (Fundaciones del Design System).
///
/// Los valores NO son inventados: un grep sobre `BorderRadius.circular(...)`
/// en todo `lib/` mostró que 14, 25, 12 y 20 son, en ese orden, los radios
/// que YA más se repiten en el código actual — este archivo les pone
/// nombre, no los cambia.
///
/// EPIC-01 solo define estos tokens. Ningún widget existente los usa
/// todavía — eso es trabajo de las épicas de UI (EPIC-06 en adelante),
/// que migran vista por vista. Por eso esta épica no produce ningún
/// cambio visible en pantalla.
class AppRadius {
  AppRadius._();

  /// Elementos chicos: inputs, chips.
  static const double sm = 12.0;

  /// Cards y contenedores — el radio MÁS repetido en el código actual
  /// (7 archivos distintos ya usan `BorderRadius.circular(14)`).
  static const double md = 14.0;

  /// Superficies grandes: bottom sheets, diálogos. Mismo valor que ya
  /// usa, por ejemplo, `selector_tipo_incidente.dart` para el sheet.
  static const double lg = 20.0;

  /// Botones de ancho completo (forma "pill") — mismo valor exacto que
  /// `ElevatedButtonThemeData` ya define hoy en `main.dart`.
  static const double pill = 25.0;

  static const BorderRadius borderSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius borderMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius borderLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius borderPill =
      BorderRadius.all(Radius.circular(pill));
}