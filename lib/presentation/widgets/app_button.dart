import 'package:flutter/material.dart';

import '../../core/app_radius.dart';
import '../../core/colores_app.dart';

/// Variantes visuales de [AppButton].
enum AppButtonVariant {
  /// Acción principal de la pantalla (fondo sólido, `AppColors.verdeOscuro`).
  primary,

  /// Acción secundaria (fondo sólido, `AppColors.negroTexto` — mismo tono
  /// que ya usa `ElevatedButtonThemeData` en `main.dart` hoy).
  secondary,

  /// Acción destructiva/irreversible (cancelar, eliminar). Fondo sólido,
  /// `AppColors.error`.
  danger,

  /// Acción de menor jerarquía visual — solo borde, sin relleno.
  outlined,
}

/// Botón de acción reutilizable — EPIC-03 (Design System, auditoría UX/UI).
///
/// Resuelve el hallazgo #1 (parcialmente — se conecta en EPIC-04):
/// hoy, cada vista maneja el estado "cargando" de un botón a mano y de
/// forma inconsistente. El patrón más común (`login_view.dart`,
/// `register_denunciante_view.dart`, etc.) es:
/// ```dart
/// sesion.isLoading
///     ? const CircularProgressIndicator()
///     : ElevatedButton(...)
/// ```
/// Esto **reemplaza** el botón entero por un spinner suelto — el botón
/// desaparece, el layout salta de tamaño, y se pierde el contexto visual
/// de "esta acción específica está en curso" (viola la heurística de
/// Nielsen #1, visibilidad del estado del sistema). [AppButton] resuelve
/// esto manteniendo el MISMO tamaño del botón y mostrando el spinner
/// adentro, en el lugar del texto — sin saltos de layout.
///
/// No se conecta a ninguna vista existente en esta épica — eso es
/// EPIC-04. Nace correcto y con tests propios.
///
/// Uso:
/// ```dart
/// AppButton(
///   label: 'Iniciar sesión',
///   isLoading: sesion.isLoading,
///   onPressed: () => _onLoginPressed(sesion),
/// )
///
/// AppButton(
///   label: 'Cancelar emergencia',
///   variant: AppButtonVariant.danger,
///   onPressed: _cancelar,
/// )
/// ```
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;

  /// Mientras es `true`: el botón mantiene su tamaño, muestra un spinner
  /// en vez del texto, y [onPressed] se ignora (no se puede volver a
  /// tocar mientras la acción está en curso — previene doble-submit,
  /// heurística #5).
  final bool isLoading;

  /// Ícono opcional antes del texto. Se oculta mientras [isLoading].
  final IconData? icon;

  /// `true` (default) — ancho completo, igual que todos los botones de
  /// acción principal existentes hoy (`minimumSize: Size(double.infinity, 50)`).
  final bool fullWidth;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final estilo = _estiloPorVariante(variant);
    final deshabilitado = isLoading || onPressed == null;

    final boton = ElevatedButton(
      onPressed: deshabilitado ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: estilo.fondo,
        foregroundColor: estilo.texto,
        disabledBackgroundColor: estilo.fondo?.withValues(alpha: 0.5),
        disabledForegroundColor: estilo.texto?.withValues(alpha: 0.7),
        elevation: variant == AppButtonVariant.outlined ? 0 : null,
        side: estilo.borde,
        minimumSize: fullWidth ? const Size(double.infinity, 50) : null,
        padding: fullWidth
            ? null
            : const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
      // Semantics explícito: mientras isLoading, el botón sigue siendo
      // "tocable" a nivel de hitbox por un momento hasta que Flutter
      // registra onPressed:null, así que el estado accesible debe
      // anunciar claramente que la acción está en curso.
      child: isLoading
          ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: estilo.texto ?? Colors.white,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
    );

    return Semantics(
      button: true,
      enabled: !deshabilitado,
      label: isLoading ? '$label, cargando' : label,
      excludeSemantics: true,
      child: boton,
    );
  }

  _EstiloBoton _estiloPorVariante(AppButtonVariant v) => switch (v) {
        AppButtonVariant.primary => const _EstiloBoton(
            fondo: AppColors.verdeOscuro,
            texto: Colors.white,
          ),
        AppButtonVariant.secondary => const _EstiloBoton(
            fondo: AppColors.negroTexto,
            texto: Colors.white,
          ),
        AppButtonVariant.danger => const _EstiloBoton(
            fondo: AppColors.error,
            texto: Colors.white,
          ),
        AppButtonVariant.outlined => const _EstiloBoton(
            fondo: Colors.transparent,
            texto: AppColors.verdeOscuro,
            borde: BorderSide(color: AppColors.verdeOscuro, width: 1.5),
          ),
      };
}

class _EstiloBoton {
  final Color? fondo;
  final Color? texto;
  final BorderSide? borde;
  const _EstiloBoton({this.fondo, this.texto, this.borde});
}