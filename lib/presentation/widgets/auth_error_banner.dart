import 'package:flutter/material.dart';

/// Banner de error reutilizable para formularios de autenticación —
/// EPIC-13 (Design System, auditoría UX/UI): "auditar y unificar
/// loading/success/error/empty en TODAS las pantallas restantes".
///
/// Antes de esta épica, [LoginView], [LoginPoliciaView],
/// [RegisterDenuncianteView] y [RegisterPoliciaView] repetían, CADA UNA
/// por separado, el mismo bloque:
/// ```dart
/// if (sesion.errorMessage != null) ...[
///   const SizedBox(height: 8),
///   Text(sesion.errorMessage!, style: const TextStyle(color: Colors.red)),
/// ],
/// ```
/// — un `Text` rojo suelto, sin ícono ni fondo, visualmente muy por
/// debajo del error card que ya usa `ReporteHallazgosView` (EPIC-10,
/// fondo `Colors.red.shade50` + ícono + borde). Mismo tipo de mensaje
/// (error de red/negocio), tratamiento visual distinto según en qué
/// pantalla aparezca — exactamente la inconsistencia que esta épica
/// pide unificar (heurística #9 — ayudar a reconocer/diagnosticar
/// errores: un error que no se destaca visualmente es más fácil de
/// pasar por alto).
///
/// [AuthErrorBanner] adopta el estilo de `ReporteHallazgosView` como
/// fuente de verdad única — de ahora en más, cualquier pantalla con un
/// error de sesión/formulario usa este widget en vez de reinventar el
/// `Text` rojo.
class AuthErrorBanner extends StatelessWidget {
  final String mensaje;

  const AuthErrorBanner({required this.mensaje, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensaje,
              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}