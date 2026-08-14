import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_routes.dart';
import '../../core/colores_app.dart';
import '../../data/models/enums/tipo_incidente_enum.dart';
import '../../data/models/tipo_incidente_presentacion.dart';
import '../../data/services/incidente_service.dart';
import '../viewmodels/crear_incidente_viewmodel.dart';
import '../viewmodels/incidente_list_viewmodel.dart';
import '../viewmodels/sesion_viewmodel.dart';
import '../widgets/incidente_list_body.dart';
import '../widgets/incidente_card.dart';

/// Home del denunciante.
///
/// F.2 — Home views por rol + Detalle de Incidente.
///
/// - FAB "EMERGENCIA" → bottom sheet de creación (F.1).
/// - Lista de `GET /mis-incidentes` con [IncidenteCard].
/// - Tap → [DetalleIncidenteView].
class HomeDenuncianteView extends StatefulWidget {
  const HomeDenuncianteView({super.key});

  @override
  State<HomeDenuncianteView> createState() => _HomeDenuncianteViewState();
}

class _HomeDenuncianteViewState extends State<HomeDenuncianteView> {
  late IncidenteListViewModel _listVm;

  @override
  void initState() {
    super.initState();
    final service = context.read<IIncidenteService>();
    _listVm = IncidenteListViewModel(
      service: service,
      fetchFn: service.misIncidentes,
    );
    _listVm.cargar();
  }

  @override
  void dispose() {
    _listVm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sesion = context.watch<SesionViewModel>();

    return ChangeNotifierProvider.value(
      value: _listVm,
      child: Scaffold(
        backgroundColor: AppColors.blancoVerde,
        appBar: AppBar(
          backgroundColor: AppColors.verdeOscuro,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('CallSOS',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              Text(sesion.nombreMostrar,
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () async {
                await sesion.logout();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(
                      context, AppRoutes.roleSelection);
                }
              },
            ),
          ],
        ),
        body: Consumer<IncidenteListViewModel>(
          builder: (_, vm, _) => IncidenteListBody(
            vm: vm,
            incidentes: vm.incidentes,
            mensajeVacio: 'Aún no has reportado ninguna emergencia.\n'
                'Usa el botón rojo para reportar.',
            iconoVacio: Icons.emergency_share_outlined,
            buildCard: (incidente) => IncidenteCard(
              incidente: incidente,
              onTap: () => Navigator.pushNamed(
                context,
                AppRoutes.detalleIncidente,
                arguments: {'incidenteId': incidente.id},
              ),
              // Cancelar — solo si el incidente está activo
              labelAccion: incidente.estaActivo ? 'Cancelar emergencia' : null,
              onAccion: incidente.estaActivo
                  ? () async {
                      // Épica 8, Bloque 1: cancelar una emergencia real es
                      // irreversible — antes, un solo tap accidental la
                      // cancelaba sin ningún paso intermedio.
                      final confirmar = await _confirmarCancelacion(context);
                      if (!confirmar || !context.mounted) return;

                      final ok = await vm.ejecutarTransicion(
                        incidenteId: incidente.id,
                        accion: () =>
                            context.read<IIncidenteService>().cancelar(incidente.id),
                      );
                      if (ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Emergencia cancelada.'),
                              backgroundColor: Colors.orange),
                        );
                      }
                    }
                  : null,
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: Colors.red,
          icon: const Icon(Icons.emergency_share, color: Colors.white),
          label: const Text('EMERGENCIA',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          onPressed: () => _abrirBottomSheet(context),
        ),
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
        child: _BottomSheetCrearIncidente(
          onExito: () => _listVm.refrescar(),
        ),
      ),
    );
  }

  /// Épica 8, Bloque 1 — confirmación antes de cancelar una emergencia
  /// real. Devuelve `true` solo si el usuario elige explícitamente
  /// "Sí, cancelar"; cualquier otro cierre del diálogo (botón "No",
  /// tocar afuera, back) se interpreta como "no cancelar".
  Future<bool> _confirmarCancelacion(BuildContext context) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Cancelar emergencia?'),
        content: const Text(
          'Esta acción no se puede deshacer. Si ya hay un agente asignado '
          'o en camino, dejará de atender este caso.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('No, volver'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    return confirmado ?? false;
  }
}

// ─── Bottom Sheet (reutilizado desde F.1, ahora refresca la lista) ────────────

class _BottomSheetCrearIncidente extends StatefulWidget {
  final VoidCallback onExito;
  const _BottomSheetCrearIncidente({required this.onExito});

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
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.emergency_share_rounded,
                            color: Colors.red, size: 28),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text('¿Qué está ocurriendo?',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Text('Selecciona el tipo de emergencia.',
                        style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 20),
                    const Text('Tipo de emergencia *',
                        style: TextStyle(fontWeight: FontWeight.w600)),
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
                        final p = catalogoTipos[tipo]!;
                        final sel = vm.tipoSeleccionado == tipo;
                        return GestureDetector(
                          onTap: () => vm.seleccionarTipo(tipo),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              color: sel
                                  ? p.color
                                  : p.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: sel
                                    ? p.color
                                    : p.color.withValues(alpha: 0.3),
                                width: sel ? 2 : 1,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            child: Row(
                              children: [
                                Icon(p.icono,
                                    color: sel ? Colors.white : p.color,
                                    size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(p.titulo,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: sel
                                              ? Colors.white
                                              : AppColors.negroTexto),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text('Descripción *',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descripcionController,
                      maxLines: 3,
                      maxLength: 300,
                      onChanged: (v) => vm.descripcion = v,
                      decoration: InputDecoration(
                        hintText:
                            'Describe brevemente lo que está ocurriendo...',
                        hintStyle: const TextStyle(
                            fontSize: 13, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                                color: Colors.grey.shade300)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                                color: Colors.grey.shade300)),
                      ),
                    ),
                    if (vm.errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(children: [
                          Icon(Icons.error_outline,
                              color: Colors.red.shade600, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(vm.errorMessage!,
                                style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 13)),
                          ),
                        ]),
                      ),
                    ],
                    if (vm.estado ==
                        CrearIncidenteEstado.obtenendoUbicacion) ...[
                      const SizedBox(height: 12),
                      const Row(children: [
                        SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2)),
                        SizedBox(width: 10),
                        Text('Obteniendo tu ubicación GPS...',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey)),
                      ]),
                    ],
                    if (vm.estado == CrearIncidenteEstado.enviando) ...[
                      const SizedBox(height: 12),
                      const Row(children: [
                        SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2)),
                        SizedBox(width: 10),
                        Text('Reportando emergencia...',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey)),
                      ]),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          vm.isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.verdeOscuro),
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
                      onPressed:
                          (vm.formularioValido && !vm.isLoading)
                              ? () async {
                                  final ok = await vm.crearIncidente(
                                    denuncianteId:
                                        sesion.actorId ?? '',
                                  );
                                  if (ok && context.mounted) {
                                    widget.onExito();
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(const SnackBar(
                                      content: Text(
                                          '✅ Emergencia reportada. Las autoridades han sido notificadas.'),
                                      backgroundColor: Colors.green,
                                      duration: Duration(seconds: 4),
                                    ));
                                  }
                                }
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            Colors.grey.shade300,
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
                                  color: Colors.white,
                                  strokeWidth: 2))
                          : const Text('Reportar emergencia',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold)),
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