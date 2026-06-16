import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/colores_app.dart';
import '../viewmodels/sesion_viewmodel.dart';

/// Home de Comando — vista de alto nivel de todos los incidentes.
///
/// F.0.5 — Esqueleto navegable.
///
/// Reemplaza definitivamente a `comando_widget.dart`.
///
/// Rol: [Rol.COMANDO] — permisos exclusivos: derivar incidentes a CAI
/// (`PATCH /{id}/derivar`), auditoría (`GET /auditoria/incidente/{id}`),
/// reportes administrativos (`POST /reportes/administrativo`).
///
/// Contenido final (F.2):
/// - Tabs: "Reportados" (CREADO, pendientes de derivar) / "Delegados".
/// - Acción "Derivar a CAI": muestra CAI sugerido (el más cercano por
///   Haversine, que el backend seleccionará automáticamente) + botón
///   confirmar → `PATCH /{id}/derivar`.
/// - Tap en incidente → [DetalleIncidenteView].
class HomeComandoView extends StatelessWidget {
  const HomeComandoView({super.key});

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
              'Centro de Comando',
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
            Icon(Icons.security, size: 60, color: AppColors.negroTexto),
            SizedBox(height: 16),
            Text(
              'Incidentes reportados y delegados\n— TODO F.2',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.negroTexto, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}