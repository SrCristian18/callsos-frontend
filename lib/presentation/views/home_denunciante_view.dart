import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_routes.dart';
import '../../core/colores_app.dart';
import '../../data/models/enums/tipo_incidente_enum.dart';
import '../../data/models/tipo_incidente_presentacion.dart';
import '../viewmodels/crear_incidente_viewmodel.dart';
import '../viewmodels/sesion_viewmodel.dart';

/// Home del denunciante — pantalla principal para reportar emergencias.
///
/// F.1 — Flujo de creación de incidente (botón de pánico).
///
/// Contiene:
/// - AppBar con [SesionViewModel.nombrePlaceholder] + logout.
/// - FAB rojo "EMERGENCIA" que abre [_BottomSheetCrearIncidente].
/// - Lista de incidentes reportados (TODO F.2 — por ahora placeholder).
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
                Navigator.pushReplacementNamed(context, AppRoutes.roleSelection);
              }
            },
          ),
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.list_alt_outlined, size: 60, color: AppColors.verdeOscuro),
            SizedBox(height: 16),
            Text(
              'Historial de incidentes\n— TODO F.2 —',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.negroTexto, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Usa el botón rojo para reportar una emergencia',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.red,
        icon: const Icon(Icons.emergency_share, color: Colors.white),
        label: const Text(
          'EMERGENCIA',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: () => _abrirBottomSheet(context),
      ),
    );
  }

  Future<void> _abrirBottomSheet(BuildContext context) async {
    final vm = context.read<CrearIncidenteViewModel>();
    vm.resetear();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: vm,
        child: const _BottomSheetCrearIncidente(),
      ),
    );
  }
}

/// Bottom sheet que contiene el flujo de creación de incidente.
class _BottomSheetCrearIncidente extends StatefulWidget {
  const _BottomSheetCrearIncidente();

  @override
  State<_BottomSheetCrearIncidente> createState() =>
      _BottomSheetCrearIncidenteState();
}

class _BottomSheetCrearIncidenteState
    extends State<_BottomSheetCrearIncidente> {
  final _descripcionController = TextEditingController();

  @override
  void dispose() {
    _descripcionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CrearIncidenteViewModel>();
    final sesion = context.read<SesionViewModel>();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Título
                      Row(
                        children: [
                          const Icon(Icons.emergency_share_rounded,
                              color: Colors.red, size: 28),
                          const SizedBox(width: 10),
                          const Text(
                            '¿Qué está ocurriendo?',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Selecciona el tipo de emergencia y añade detalles.',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),

                      const SizedBox(height: 20),

                      // Grid de tipos de incidente
                      const Text(
                        'Tipo de emergencia *',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 2.6,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: TipoIncidenteEnum.values.length,
                        itemBuilder: (_, i) {
                          final tipo = TipoIncidenteEnum.values[i];
                          final presentacion = catalogoTipos[tipo]!;
                          final seleccionado = vm.tipoSeleccionado == tipo;

                          return GestureDetector(
                            onTap: () => vm.seleccionarTipo(tipo),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              decoration: BoxDecoration(
                                color: seleccionado
                                    ? presentacion.color
                                    : presentacion.color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: seleccionado
                                      ? presentacion.color
                                      : presentacion.color.withOpacity(0.3),
                                  width: seleccionado ? 2 : 1,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              child: Row(
                                children: [
                                  Icon(
                                    presentacion.icono,
                                    color: seleccionado
                                        ? Colors.white
                                        : presentacion.color,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      presentacion.titulo,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: seleccionado
                                            ? Colors.white
                                            : AppColors.negroTexto,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // Descripción opcional
                      const Text(
                        'Descripción (opcional)',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _descripcionController,
                        maxLines: 3,
                        maxLength: 300,
                        onChanged: (v) => vm.descripcion = v,
                        decoration: InputDecoration(
                          hintText:
                              'Describe brevemente lo que está ocurriendo...',
                          hintStyle:
                              const TextStyle(fontSize: 13, color: Colors.grey),
                          filled: true,
                          fillColor: Colors.grey.shade50,
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
                        ),
                      ),

                      // Error message
                      if (vm.errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline,
                                  color: Colors.red.shade600, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  vm.errorMessage!,
                                  style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Estado obteniendo ubicación
                      if (vm.estado ==
                          CrearIncidenteEstado.obtenendoUbicacion) ...[
                        const SizedBox(height: 12),
                        const Row(
                          children: [
                            SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2)),
                            SizedBox(width: 10),
                            Text('Obteniendo tu ubicación GPS...',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey)),
                          ],
                        ),
                      ],

                      if (vm.estado == CrearIncidenteEstado.enviando) ...[
                        const SizedBox(height: 12),
                        const Row(
                          children: [
                            SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2)),
                            SizedBox(width: 10),
                            Text('Reportando emergencia...',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.grey)),
                          ],
                        ),
                      ],

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // Botones de acción
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: vm.isLoading
                            ? null
                            : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: AppColors.verdeOscuro),
                          foregroundColor: AppColors.negroTexto,
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (vm.formularioValido && !vm.isLoading)
                            ? () async {
                                final ok = await vm.crearIncidente(
                                  denuncianteId: sesion.actorId ?? '',
                                );
                                if (ok && context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          '✅ Emergencia reportada. Las autoridades han sido notificadas.'),
                                      backgroundColor: Colors.green,
                                      duration: Duration(seconds: 4),
                                    ),
                                  );
                                  // TODO(F.2): navegar a DetalleIncidenteView
                                  // cuando exista la vista completa.
                                }
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: vm.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'Reportar emergencia',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}