import 'package:flutter/material.dart';

import '../../core/colores_app.dart';

/// Diálogo de confirmación reutilizable — EPIC-03 (Design System,
/// auditoría UX/UI).
///
/// Generaliza el patrón que ya existe repetido y ligeramente distinto
/// en varios lugares (`home_denunciante_view._confirmarCancelacion`,
/// diálogos de asignar/derivar en CAI/Comando): un `AlertDialog` con
/// dos acciones, donde solo la opción explícita de confirmar devuelve
/// `true` — cerrar el diálogo de cualquier otra forma (botón
/// secundario, tocar afuera, back del sistema) se interpreta siempre
/// como "no confirmar". Previene acciones destructivas accidentales
/// (heurística #5).
///
/// No se conecta a ninguna vista existente en esta épica — EPIC-04.
///
/// Uso:
/// ```dart
/// final confirmado = await ConfirmationDialog.show(
///   context,
///   title: '¿Cancelar emergencia?',
///   message: 'Esta acción no se puede deshacer...',
///   confirmText: 'Sí, cancelar',
///   isDangerous: true,
/// );
/// if (confirmado) { ... }
/// ```
class ConfirmationDialog {
  ConfirmationDialog._();

  /// Muestra el diálogo y devuelve `true` únicamente si el usuario tocó
  /// el botón de confirmar. Cualquier otro cierre (botón cancelar,
  /// tocar afuera, back) devuelve `false` — nunca `null`, así que el
  /// llamador no necesita manejar el caso `?? false` cada vez.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirmar',
    String cancelText = 'Cancelar',

    /// `true` para acciones destructivas/irreversibles (cancelar,
    /// eliminar, derivar sin vuelta atrás) — el botón de confirmar se
    /// muestra en rojo (`AppColors.error`) en vez del verde de marca,
    /// para que la severidad de la acción sea visible antes de tocarlo.
    bool isDangerous = false,

    /// `false` (default) impide cerrar tocando afuera del diálogo —
    /// fuerza una decisión explícita. Poner en `true` para
    /// confirmaciones de bajo riesgo donde "tocar afuera = cancelar"
    /// es un atajo razonable.
    bool barrierDismissible = false,
  }) async {
    final confirmado = await showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(cancelText),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: isDangerous ? AppColors.error : AppColors.verdeOscuro,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              confirmText,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    return confirmado ?? false;
  }
}