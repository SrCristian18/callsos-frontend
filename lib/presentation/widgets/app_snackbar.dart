import 'package:flutter/material.dart';

/// Épica 8, Bloque 5 (Optimización de UX) — SnackBars consistentes.
///
/// Antes, cada vista armaba su propio `SnackBar` a mano (7 sitios:
/// `detalle_incidente_view`, `home_cai_view`, `home_comando_view`,
/// `home_denunciante_view` ×2, `reporte_hallazgos_view`). El color por
/// tipo de resultado ya coincidía por convención (verde=éxito,
/// rojo=error, naranja=advertencia) en los 7, pero sin nada que lo
/// garantizara hacia adelante — el próximo SnackBar que alguien agregue
/// podría usar cualquier tono de verde, olvidar la duración, etc. Este
/// helper centraliza color y duración por tipo, una sola vez.
///
/// Deliberadamente NO se cambió `behavior` a `SnackBarBehavior.floating`
/// (que le daría un estilo de tarjeta flotante con bordes redondeados) —
/// eso sería un cambio de diseño visual, no solo de consistencia, y no
/// es parte de lo que pidió este bloque. La app sigue mostrando el
/// SnackBar de ancho completo de siempre (`SnackBarBehavior.fixed`,
/// el default de Flutter).
class AppSnackBar {
  AppSnackBar._();

  static const Duration _duracion = Duration(seconds: 4);

  /// Resultado positivo de una acción (ej. "Agente asignado
  /// exitosamente.", "Emergencia reportada.").
  static void exito(BuildContext context, String mensaje) {
    _mostrar(context, mensaje, Colors.green);
  }

  /// Error de negocio o de red — [mensaje] debe ser siempre texto
  /// pensado para el usuario final (típicamente `ApiException.message`),
  /// nunca `Exception.toString()` crudo.
  static void error(BuildContext context, String mensaje) {
    _mostrar(context, mensaje, Colors.red);
  }

  /// Resultado neutro/atención pero no un error (ej. "Emergencia
  /// cancelada.").
  static void advertencia(BuildContext context, String mensaje) {
    _mostrar(context, mensaje, Colors.orange);
  }

  static void _mostrar(BuildContext context, String mensaje, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: color,
        duration: _duracion,
      ),
    );
  }
}