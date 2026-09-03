import 'package:flutter/material.dart';

/// Paleta de la app.
///
/// EPIC-01 (Fundaciones del Design System) amplía este archivo con
/// colores semánticos y de rol, SIN modificar los 4 colores originales
/// de abajo — son la identidad de marca ya validada por el usuario;
/// ninguna vista existente debe verse distinta tras esta épica.
class AppColors{
  static const Color blancoVerde = Color(0xfff6ffe3);
  static const Color verdeClaro = Color(0xff7ead1f);
  static const Color verdeOscuro = Color(0xff1e9a20);
  static const Color negroTexto = Color(0xFF1B2A3B);

  // ── Semánticos (EPIC-01) ────────────────────────────────────────────
  // Hoy la app usa Colors.red/Colors.green de Material directo para
  // estados de error/éxito (ej. botón "Cancelar emergencia", chip de
  // estado FINALIZADO) — estas constantes les dan un nombre propio
  // dentro del sistema, sin reemplazar ningún uso todavía. Migrar cada
  // vista a estos tokens es trabajo de las épicas de UI, no de esta.
  static const Color error = Color(0xFFD32F2F);
  static const Color warning = Color(0xFFED6C02);
  static const Color success = Color(0xFF2E7D32);
  static const Color info = Color(0xFF0288D1);

  // ── Paleta por rol (EPIC-01) ─────────────────────────────────────────
  // Resuelve el hallazgo #6 de la auditoría UX/UI: hoy AGENTE y
  // COMANDO comparten el mismo color (negroTexto) y OPERADOR_CAI usa
  // un verde escrito a mano (Colors.green.shade700) sin pasar por este
  // archivo. Estas constantes son la fuente única que EPIC-06
  // (RoleHeader) va a consumir — ningún AppBar existente las usa
  // todavía, así que definirlas acá no cambia nada en pantalla hoy.
  static const Color acentoDenunciante = verdeOscuro; // se conserva tal cual
  static const Color acentoAgente = Color(0xFF2C5F7C);
  static const Color acentoOperadorCai = Color(0xFF0F7B6C);
  static const Color acentoComando = Color(0xFF16223A);

  // ── Dark mode (EPIC-02) ──────────────────────────────────────────────
  // Valores tomados directamente de la propuesta de la auditoría UX/UI
  // (sección 4.3): superficies invertidas derivadas de la MISMA paleta,
  // no una paleta nueva — primary/secondary/error/etc. se mantienen
  // iguales entre light y dark (ver main.dart), solo cambian los fondos.
  static const Color fondoOscuro = Color(0xFF121820); // scaffold + surface
  static const Color superficieOscura = Color(0xFF1B2531); // inputs, cards elevadas

  // ── Accesibilidad — contraste AA (EPIC-14) ──────────────────────────
  // `verdeClaro` (#7EAD1F) sobre blanco/blancoVerde da 2.58–2.66:1 — muy
  // por debajo del mínimo AA para texto (4.5:1 texto normal, 3:1 texto
  // grande ≥18pt/≥14pt-bold; esto no llega ni al umbral de texto
  // grande). Se usaba como color de TEXTO en 4 pantallas (enlaces
  // "¿Olvidaste tu contraseña?", subtítulo de `SplashView`) — casos
  // reales, ya en pantalla, no hipotéticos.
  //
  // `verdeTexto` es el mismo verde de marca (mismo matiz/saturación),
  // solo más oscuro, pensado específicamente para texto/íconos sobre
  // fondos claros — NO reemplaza a `verdeClaro` en sus demás usos
  // (íconos decorativos en inputs, `ColorScheme.secondary`, fondos):
  // `verdeClaro` en sí NO se toca, seguimos el mismo criterio que
  // EPIC-01 ya estableció para los 4 colores originales ("identidad de
  // marca ya validada, no se modifica el swatch existente").
  //
  // 4.78:1 contra blanco, 4.63:1 contra `blancoVerde` — pasa AA para
  // texto normal en ambos.
  static const Color verdeTexto = Color(0xFF5B7D16);
}