import 'package:flutter/material.dart';

/// Escala de espaciado — EPIC-01 (Fundaciones del Design System).
///
/// Grounded en los valores más usados hoy en `SizedBox(height: ...)` en
/// todo `lib/` (20 y 10 son, de hecho, los más repetidos, seguidos de
/// 8, 16, 12 y 4) — esta escala los ordena en una progresión
/// consistente para uso futuro. Ningún `SizedBox` existente se toca en
/// esta épica.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;

  // Gaps ya armados como SizedBox — evitan escribir
  // `SizedBox(height: AppSpacing.md)` a mano en cada vista que migre.
  static const SizedBox gapXs = SizedBox(height: xs, width: xs);
  static const SizedBox gapSm = SizedBox(height: sm, width: sm);
  static const SizedBox gapMd = SizedBox(height: md, width: md);
  static const SizedBox gapLg = SizedBox(height: lg, width: lg);
  static const SizedBox gapXl = SizedBox(height: xl, width: xl);
  static const SizedBox gapXxl = SizedBox(height: xxl, width: xxl);
}