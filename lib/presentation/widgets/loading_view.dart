import 'package:flutter/material.dart';

import '../../core/colores_app.dart';

/// Estado de carga reutilizable — EPIC-03 (Design System, auditoría
/// UX/UI).
///
/// Extrae el spinner centrado que hoy se repite, casi idéntico, en
/// `incidente_list_body.dart` (`vm.isLoading`), `tracking_view.dart` y
/// otros lugares que cargan datos antes de mostrar la pantalla. No se
/// conecta a ninguna vista existente en esta épica — EPIC-04.
///
/// Uso:
/// ```dart
/// if (vm.isLoading) return const LoadingView();
/// if (vm.isLoading) return const LoadingView(mensaje: 'Cargando incidente...');
/// ```
class LoadingView extends StatelessWidget {
  final String? mensaje;

  const LoadingView({super.key, this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.verdeOscuro),
          if (mensaje != null) ...[
            const SizedBox(height: 16),
            Text(
              mensaje!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}