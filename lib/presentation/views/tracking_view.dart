import 'package:flutter/material.dart';

import '../../core/colores_app.dart';

/// Vista de seguimiento en tiempo real del agente en camino.
///
/// F.0.5 — Esqueleto navegable.
///
/// Recibe `incidenteId` como argumento de ruta:
/// ```dart
/// Navigator.pushNamed(context, '/tracking',
///   arguments: {'incidenteId': 'inc-001'});
/// ```
///
/// Contenido final (F.3):
/// - Mapa [flutter_map] con marcador de la posición del denunciante y del
///   agente.
/// - [TrackingViewModel] (a crear en F.3) que suscribe al canal STOMP
///   `/topic/incidente/{id}/ubicacion` via `stomp_dart_client`.
/// - El agente también emite su posición en tiempo real a
///   `/app/ubicacion/{incidenteId}` usando [GeolocalizacionService]
///   (F.0.6).
class TrackingView extends StatelessWidget {
  const TrackingView({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final incidenteId = args?['incidenteId'] as String? ?? '—';

    return Scaffold(
      backgroundColor: AppColors.blancoVerde,
      appBar: AppBar(
        backgroundColor: AppColors.verdeOscuro,
        title: const Text(
          'Seguimiento en tiempo real',
          style: TextStyle(color: Colors.white),
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
            const Icon(Icons.map, size: 60, color: AppColors.verdeOscuro),
            const SizedBox(height: 16),
            Text(
              'Mapa de tracking\nIncidente: $incidenteId',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.negroTexto, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'flutter_map + STOMP WebSocket — TODO F.3',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}