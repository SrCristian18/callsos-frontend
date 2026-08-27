import 'package:flutter/material.dart';

import '../../core/colores_app.dart';

/// Estado de error reutilizable, con botón de reintento opcional —
/// EPIC-03 (Design System, auditoría UX/UI).
///
/// Extrae el bloque ícono+mensaje+"Reintentar" que hoy se repite,
/// prácticamente idéntico, en `incidente_list_body.dart` y
/// `tracking_view.dart` (mismo ícono `wifi_off_outlined`, mismo tamaño
/// 52, mismos tonos de gris). No se conecta a ninguna vista existente
/// en esta épica — EPIC-04.
///
/// Uso:
/// ```dart
/// if (vm.errorMessage != null) {
///   return ErrorView(
///     message: vm.errorMessage!,
///     onRetry: vm.cargar,
///   );
/// }
/// ```
class ErrorView extends StatelessWidget {
  final String message;
  final IconData icon;

  /// Si es `null`, no se muestra el botón de reintento (error sin
  /// acción posible, ej. dentro de un diálogo).
  final VoidCallback? onRetry;
  final String retryLabel;

  const ErrorView({
    super.key,
    required this.message,
    this.icon = Icons.wifi_off_outlined,
    this.onRetry,
    this.retryLabel = 'Reintentar',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 52, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: Text(retryLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.verdeOscuro,
                  foregroundColor: Colors.white,
                ),
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}