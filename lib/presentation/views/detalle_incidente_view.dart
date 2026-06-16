import 'package:flutter/material.dart';

import '../../core/colores_app.dart';

/// Detalle completo de un incidente.
///
/// F.0.5 — Esqueleto navegable.
///
/// Recibe `incidenteId` como argumento de ruta:
/// ```dart
/// Navigator.pushNamed(context, '/detalle_incidente',
///   arguments: {'incidenteId': 'inc-001'});
/// ```
///
/// Contenido final (F.2):
/// - Llama `GET /incidentes/{id}` y muestra todos los campos de
///   [Incidente]: tipo, descripción, estado ([EstadoChip]), ubicación,
///   fecha, CAI asignado, agente asignado.
/// - Botones contextuales según rol + estado actual:
///   · AGENTE + AGENTE_ASIGNADO → "Ir en camino" (→ F.3 TrackingView).
///   · AGENTE + EN_ATENCION → "Finalizar" (→ F.4 ReporteHallazgosView).
///   · DENUNCIANTE + AGENTE_EN_CAMINO → "Ver en mapa" (→ F.3 TrackingView).
///   · Cualquier rol activo → "Cancelar incidente".
/// - Polling o WebSocket de estado para actualizar en tiempo real (F.3).
class DetalleIncidenteView extends StatelessWidget {
  const DetalleIncidenteView({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final incidenteId = args?['incidenteId'] as String? ?? '—';

    return Scaffold(
      backgroundColor: AppColors.blancoVerde,
      appBar: AppBar(
        backgroundColor: AppColors.verdeOscuro,
        title: Text(
          'Incidente #$incidenteId',
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, size: 60, color: AppColors.verdeOscuro),
            const SizedBox(height: 16),
            Text(
              'Detalle del incidente\n$incidenteId',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.negroTexto, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              '— TODO F.2 —',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),

            // Placeholder de botones contextuales — se implementan en F.2.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Ver en mapa (F.3)'),
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/tracking',
                      arguments: {'incidenteId': incidenteId},
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.assignment),
                    label: const Text('Reporte de hallazgos (F.4)'),
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/reporte_hallazgos',
                      arguments: {'incidenteId': incidenteId},
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}