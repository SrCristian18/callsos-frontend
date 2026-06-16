import 'package:flutter/material.dart';

import '../../core/colores_app.dart';

/// Formulario de reporte de hallazgos — completado por el agente al
/// finalizar la atención de un incidente.
///
/// F.0.5 — Esqueleto navegable.
///
/// Recibe `incidenteId` como argumento de ruta:
/// ```dart
/// Navigator.pushNamed(context, '/reporte_hallazgos',
///   arguments: {'incidenteId': 'inc-001'});
/// ```
///
/// Contenido final (F.4):
/// - Campo de texto para descripción/hallazgos.
/// - Botón "Enviar" → llama [IReporteService.crearHallazgos] +
///   `PATCH /{id}/evaluar` → navega a [HomeAgenteView].
/// - El [ReporteHallazgosViewModel] (a crear en F.4) maneja estado
///   isLoading/error y la coordinación de ambas llamadas.
class ReporteHallazgosView extends StatelessWidget {
  const ReporteHallazgosView({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final incidenteId = args?['incidenteId'] as String? ?? '—';

    return Scaffold(
      backgroundColor: AppColors.blancoVerde,
      appBar: AppBar(
        backgroundColor: AppColors.negroTexto,
        title: const Text(
          'Reporte de hallazgos',
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
            const Icon(Icons.assignment_turned_in, size: 60, color: AppColors.negroTexto),
            const SizedBox(height: 16),
            Text(
              'Formulario de hallazgos\nIncidente: $incidenteId',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.negroTexto, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              '— TODO F.4 —',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}