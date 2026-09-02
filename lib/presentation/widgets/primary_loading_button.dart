import 'package:flutter/material.dart';

import '../../core/colores_app.dart';

/// Botón primario de ancho completo con spinner inline — EPIC-13
/// (Design System, auditoría UX/UI): "auditar y unificar
/// loading/success/error/empty en TODAS las pantallas restantes".
///
/// Antes de esta épica, [LoginView], [LoginPoliciaView],
/// [RegisterDenuncianteView] y [RegisterPoliciaView] repetían, CADA UNA
/// por separado, el mismo patrón para el estado de carga:
/// ```dart
/// sesion.isLoading
///     ? const CircularProgressIndicator()
///     : ElevatedButton(..., child: const Text('Iniciar sesión')),
/// ```
/// — mientras carga, el botón entero DESAPARECE y en su lugar aparece
/// un spinner chico y centrado. Eso mueve todo el layout de golpe (el
/// spinner no ocupa el mismo alto/ancho que el botón de 50px de altura
/// completa) — un salto visual innecesario en el momento donde más
/// importa que el usuario sienta que la pantalla es estable (heurística
/// #1 — visibilidad del estado del sistema). El patrón que ya usa
/// `ReporteHallazgosView` (EPIC-10) es mejor: el botón se queda en el
/// mismo lugar, mismo tamaño, deshabilitado, con un spinner CHICO
/// reemplazando solo su texto.
///
/// [PrimaryLoadingButton] adopta ese patrón como fuente de verdad
/// única. Colores por defecto = los de [LoginView]
/// (`AppColors.verdeOscuro`); las pantallas que usan otro color de
/// marca (ej. [LoginPoliciaView] con `AppColors.negroTexto`) lo pasan
/// explícito.
class PrimaryLoadingButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color foregroundColor;

  const PrimaryLoadingButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
    this.backgroundColor = AppColors.verdeOscuro,
    this.foregroundColor = Colors.white,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          disabledBackgroundColor: backgroundColor.withValues(alpha: 0.6),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        ),
        // Deshabilitado mientras carga — evita doble envío por doble
        // tap (mismo criterio que ya aplica ReporteHallazgosView).
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: foregroundColor,
                  strokeWidth: 2.4,
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  color: foregroundColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}