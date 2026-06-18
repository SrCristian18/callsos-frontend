import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_routes.dart';
import '../../core/colores_app.dart';
import '../../data/services/reporte_service.dart';
import '../viewmodels/reporte_hallazgos_viewmodel.dart';
import '../viewmodels/sesion_viewmodel.dart';

/// Formulario de reporte de hallazgos — completado por el agente al
/// finalizar la atención.
///
/// F.4 — ReporteHallazgosView + ReporteHallazgosViewModel.
///
/// Recibe `incidenteId` como argumento de ruta:
/// ```dart
/// Navigator.pushNamed(context, AppRoutes.reporteHallazgos,
///   arguments: {'incidenteId': 'inc-001'});
/// ```
///
/// DECISIÓN DE DISEÑO (F.4): este formulario llama DIRECTAMENTE a
/// `POST /reportes/hallazgos`, que finaliza el incidente internamente.
/// No se necesita (ni debe) llamar `PATCH /{id}/evaluar` por separado
/// — el backend lo hace dentro de `CrearReporteHallazgosService`.
///
/// Tras el éxito navega a [HomeAgenteView] con snackbar de confirmación.
class ReporteHallazgosView extends StatefulWidget {
  const ReporteHallazgosView({super.key});

  @override
  State<ReporteHallazgosView> createState() => _ReporteHallazgosViewState();
}

class _ReporteHallazgosViewState extends State<ReporteHallazgosView> {
  late ReporteHallazgosViewModel _vm;
  final _descripcionController = TextEditingController();
  late String _incidenteId;

  @override
  void initState() {
    super.initState();
    _vm = ReporteHallazgosViewModel(
      reporteService: context.read<IReporteService>(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _incidenteId = args?['incidenteId'] as String? ?? '';
  }

  @override
  void dispose() {
    _descripcionController.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final sesion = context.read<SesionViewModel>();
    final ok = await _vm.enviar(
      incidenteId: _incidenteId,
      agenteId: sesion.actorId ?? '',
    );

    if (ok && mounted) {
      // Navegar a HomeAgenteView eliminando el stack actual para que el
      // agente no pueda volver al formulario ya enviado.
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.homeAgente,
        (route) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '✅ Reporte enviado. Incidente finalizado correctamente.',
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _vm,
      child: Scaffold(
        backgroundColor: AppColors.blancoVerde,
        appBar: AppBar(
          backgroundColor: AppColors.negroTexto,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Reporte de hallazgos',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: Consumer<ReporteHallazgosViewModel>(
          builder: (_, vm, __) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ─────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.negroTexto,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.assignment_turned_in,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cierre del incidente',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.negroTexto,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Documenta los hallazgos. El incidente quedará '
                              'FINALIZADO tras el envío.',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Campo de descripción ────────────────────────────────
                const Text(
                  'Descripción de hallazgos *',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.negroTexto,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Describe qué encontraste al llegar, las acciones tomadas '
                  'y el estado final de la situación.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _descripcionController,
                  maxLines: 8,
                  maxLength: 1000,
                  enabled: !vm.isLoading,
                  onChanged: (v) => vm.descripcion = v,
                  decoration: InputDecoration(
                    hintText:
                        'Ej: Al llegar al lugar, las partes ya estaban '
                        'calmadas. Se tomaron datos de los involucrados y '
                        'se orientó a la familia afectada...',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: AppColors.verdeOscuro, width: 2),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                ),

                // ── Error ───────────────────────────────────────────────
                if (vm.errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(children: [
                      Icon(Icons.error_outline,
                          color: Colors.red.shade600, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          vm.errorMessage!,
                          style: TextStyle(
                              color: Colors.red.shade700, fontSize: 13),
                        ),
                      ),
                    ]),
                  ),
                ],

                const SizedBox(height: 32),

                // ── Botones ─────────────────────────────────────────────
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: AppColors.verdeOscuro),
                        foregroundColor: AppColors.negroTexto,
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: vm.isLoading
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.negroTexto,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            Colors.grey.shade300,
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed:
                          (vm.formularioValido && !vm.isLoading)
                              ? _enviar
                              : null,
                      child: vm.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2),
                            )
                          : const Text(
                              'Enviar reporte',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}