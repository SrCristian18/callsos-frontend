import 'package:flutter/material.dart';

import 'colores_app.dart';

/// Escala tipográfica — EPIC-01 (Fundaciones del Design System).
///
/// Grounded en los `fontSize` más usados hoy en todo `lib/`: un grep
/// confirma 13, 12, 14, 11, 24 y 18 como los valores que de hecho más
/// se repiten — hoy sin ninguna escala ni nombre en común (cada vista
/// elige el suyo). Esta clase consolida esos tamaños en 6 niveles con
/// nombre.
///
/// EPIC-01 solo DEFINE estos estilos y los expone también como
/// [textTheme] para que `main.dart` los ofrezca como default de
/// `ThemeData` — ningún widget existente los usa todavía (ninguna
/// vista actual lee `Theme.of(context).textTheme`, verificado antes de
/// escribir esto), así que conectarlos en `ThemeData` no cambia nada
/// en pantalla hoy. Migrar cada vista para usarlos explícitamente es
/// trabajo de las épicas de UI por rol (EPIC-09 en adelante).
class AppTextStyles {
  AppTextStyles._();

  /// Título de marca — ej. "CallSOS" en el splash. 32 ya es el
  /// `fontSize` más grande presente hoy en el código.
  static const TextStyle display = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.negroTexto,
    letterSpacing: 2,
  );

  /// Títulos de pantalla o de sección.
  static const TextStyle tituloGrande = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.negroTexto,
  );

  /// Títulos de card o de diálogo.
  static const TextStyle tituloMediano = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.negroTexto,
  );

  /// Texto de cuerpo principal.
  static const TextStyle cuerpo = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.negroTexto,
  );

  /// Texto secundario — el `fontSize` MÁS repetido en todo el código actual.
  static const TextStyle cuerpoPequeno = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.normal,
    color: AppColors.negroTexto,
  );

  /// Etiquetas, chips, metadatos (fechas, CAI asignado, etc.).
  static const TextStyle etiqueta = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.negroTexto,
  );

  /// Equivalente como [TextTheme], para ofrecer estos estilos como
  /// default en `ThemeData` sin obligar a ninguna vista a adoptarlos
  /// todavía.
  static const TextTheme textTheme = TextTheme(
    displayLarge: display,
    titleLarge: tituloGrande,
    titleMedium: tituloMediano,
    bodyLarge: cuerpo,
    bodyMedium: cuerpoPequeno,
    labelSmall: etiqueta,
  );
}