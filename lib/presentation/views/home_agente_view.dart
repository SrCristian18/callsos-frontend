import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/colores_app.dart';
import '../viewmodels/sesion_viewmodel.dart';

/// Home del Agente de Policía — cola de incidentes asignados.
///
/// F.0.5 — Esqueleto navegable.
///
/// Reemplaza definitivamente a `agente_widget.dart` (que era un `Column`
/// embebido en [IncidenteView] sin ruta propia). Con esta vista, el agente
/// navega directamente aquí tras el login.
///
/// Contenido final (F.2):
/// - Perfil (placeholder de nombre + CAI) via [SesionViewModel.nombrePlaceholder].
/// - Lista de `GET /incidentes/asignados` con [IncidenteCard] + [EstadoChip].
/// - Acciones por estado del incidente:
///   · AGENTE_ASIGNADO → botón "En camino" → `PATCH /{id}/en-camino`.
///   · AGENTE_EN_CAMINO → botón "Atender" → `PATCH /{id}/atender`.
///   · EN_ATENCION → botón "Evaluar" → `PATCH /{id}/evaluar` + navegar a
///     [ReporteHallazgosView] (F.4).
/// - Tap en incidente → [DetalleIncidenteView].
class HomeAgenteView extends StatelessWidget {
  const HomeAgenteView({super.key});

  @override
  Widget build(BuildContext context) {
    final sesion = context.watch<SesionViewModel>();

    return Scaffold(
      backgroundColor: AppColors.blancoVerde,
      appBar: AppBar(
        backgroundColor: AppColors.negroTexto,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mis asignaciones',
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
            Icon(Icons.local_police, size: 60, color: AppColors.negroTexto),
            SizedBox(height: 16),
            Text(
              'Lista de incidentes asignados\n— TODO F.2',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.negroTexto, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}