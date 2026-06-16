import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/colores_app.dart';
import '../viewmodels/sesion_viewmodel.dart';

/// Home del denunciante — pantalla principal para reportar emergencias.
///
/// F.0.5 — Esqueleto navegable.
///
/// Contenido final (F.1):
/// - Botón de pánico grande → selección de [TipoIncidenteEnum] → crear
///   incidente real via [IIncidenteService] con ubicación GPS (F.0.6).
/// - Lista de incidentes reportados (`GET /mis-incidentes`) con
///   [IncidenteCard] + [EstadoChip].
/// - Tap en incidente activo → [DetalleIncidenteView] (y posiblemente
///   [TrackingView] si el estado es AGENTE_EN_CAMINO).
///
/// Por ahora: `Scaffold` con AppBar (nombre/placeholder + logout) y un
/// cuerpo marcado como "TODO F.1".
class HomeDenuncianteView extends StatelessWidget {
  const HomeDenuncianteView({super.key});

  @override
  Widget build(BuildContext context) {
    final sesion = context.watch<SesionViewModel>();

    return Scaffold(
      backgroundColor: AppColors.blancoVerde,
      appBar: AppBar(
        backgroundColor: AppColors.verdeOscuro,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CallSOS',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            Text(
              sesion.nombrePlaceholder,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await sesion.logout();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/role_selection');
              }
            },
          ),
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emergency_share_rounded, size: 60, color: AppColors.verdeOscuro),
            SizedBox(height: 16),
            Text(
              'Botón de pánico y lista de\nincidentes — TODO F.1',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.negroTexto, fontSize: 16),
            ),
          ],
        ),
      ),
      // El FAB con el botón de pánico real se añade en F.1.
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.red,
        icon: const Icon(Icons.emergency_share, color: Colors.white),
        label: const Text('EMERGENCIA', style: TextStyle(color: Colors.white)),
        onPressed: () {
          // TODO(F.1): abrir selector de TipoIncidenteEnum y crear incidente.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Botón de pánico — se implementa en F.1')),
          );
        },
      ),
    );
  }
}