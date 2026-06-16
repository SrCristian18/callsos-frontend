import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/colores_app.dart';
import '../viewmodels/sesion_viewmodel.dart';

/// Home del Operador CAI — gestión de incidentes del CAI.
///
/// F.0.5 — Esqueleto navegable.
///
/// Reemplaza definitivamente a `jefecai_widget.dart`.
///
/// Contenido final (F.2):
/// - Header con nombre del CAI (placeholder hasta que exista endpoint de
///   perfil — ver F.0.7).
/// - Tabs: "Por Asignar" (incidentes DERIVADO_A_CAI) / "Historial".
/// - Acción "Asignar Agente": muestra opción/opciones candidatas y confirma
///   → `PATCH /{id}/asignar` (ver decisión acordada en F.0.7 — el backend
///   asigna automáticamente; la UI muestra la asignación como "opción
///   sugerida" hasta que exista endpoint de candidatos).
/// - Tap en incidente → [DetalleIncidenteView].
class HomeCAIView extends StatelessWidget {
  const HomeCAIView({super.key});

  @override
  Widget build(BuildContext context) {
    final sesion = context.watch<SesionViewModel>();

    return Scaffold(
      backgroundColor: AppColors.blancoVerde,
      appBar: AppBar(
        backgroundColor: Colors.green.shade700,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Panel CAI',
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
            Icon(Icons.domain, size: 60, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'Por Asignar / Historial del CAI\n— TODO F.2',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.negroTexto, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}