import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_routes.dart';
import '../../core/colores_app.dart';
import '../../data/models/enums/estado_incidente.dart';
import '../../data/models/incidente.dart';
import '../../data/models/invitacion_agente.dart';
import '../../data/services/api_exception.dart';
import '../../data/services/cai_service.dart';
import '../../data/services/incidente_service.dart';
import '../viewmodels/incidente_list_viewmodel.dart';
import '../viewmodels/sesion_viewmodel.dart';
import '../widgets/incidente_card.dart';
import '../widgets/incidente_list_body.dart';

/// Home de Comando.
///
/// F.2 + FIX (endpoint Gap 2 resuelto en validación end-to-end):
/// Usa el nuevo endpoint `GET /incidentes/por-estado?estado=CREADO`
/// que lista todos los incidentes pendientes de derivar sin filtrar
/// por actorId — el único endpoint que tiene sentido para COMANDO.
///
/// Tabs: "Reportados" (CREADO) / "Delegados" (resto).
class HomeComandoView extends StatefulWidget {
  const HomeComandoView({super.key});

  @override
  State<HomeComandoView> createState() => _HomeComandoViewState();
}

class _HomeComandoViewState extends State<HomeComandoView>
    with SingleTickerProviderStateMixin {
  late IncidenteListViewModel _vm;
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    final service = context.read<IIncidenteService>();
    _vm = IncidenteListViewModel(
      service: service,
      // FIX: usar el nuevo endpoint por-estado en vez de porCai()
      // que era estructuralmente incompatible con el rol COMANDO.
      fetchFn: () => service.porEstado(EstadoIncidente.CREADO),
    );
    _vm.cargar();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _vm.dispose();
    super.dispose();
  }

  /// Diálogo para generar un token de invitación de agente.
  ///
  /// LIMITACIÓN CONOCIDA: no hay endpoint de "listar CAIs" en el backend
  /// todavía (deuda_backend.md no lo contemplaba), así que Comando escribe
  /// el ID del CAI a mano en vez de elegirlo de un selector. Si se agrega
  /// ese endpoint más adelante, reemplazar este TextField por un
  /// DropdownButton poblado desde él.
  Future<void> _mostrarGenerarInvitacion(BuildContext context) async {
    final caiService = context.read<ICaiService>();
    final caiIdController = TextEditingController();
    InvitacionAgente? invitacionGenerada;
    String? error;
    bool cargando = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Generar invitación de agente'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (invitacionGenerada == null) ...[
                const Text(
                  'Escribe el ID del CAI al que quedará asignado el '
                  'agente. El token dura 48 horas y es de un solo uso.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: caiIdController,
                  decoration: const InputDecoration(
                    labelText: 'ID del CAI',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: const TextStyle(color: Colors.red)),
                ],
              ] else ...[
                const Text('Comparte este token con el agente '
                    '(verbalmente o por un canal interno):'),
                const SizedBox(height: 12),
                SelectableText(
                  invitacionGenerada!.token,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  'Expira: ${invitacionGenerada!.fechaExpiracion}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(invitacionGenerada == null ? 'Cancelar' : 'Cerrar'),
            ),
            if (invitacionGenerada == null)
              ElevatedButton(
                onPressed: cargando
                    ? null
                    : () async {
                        if (caiIdController.text.trim().isEmpty) return;
                        setDialogState(() {
                          cargando = true;
                          error = null;
                        });
                        try {
                          final invitacion = await caiService
                              .generarInvitacion(caiIdController.text.trim());
                          setDialogState(() {
                            invitacionGenerada = invitacion;
                            cargando = false;
                          });
                        } on ApiException catch (e) {
                          setDialogState(() {
                            error = e.message;
                            cargando = false;
                          });
                        }
                      },
                child: cargando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Generar'),
              ),
          ],
        ),
      ),
    );

    caiIdController.dispose();
  }

  Future<void> _mostrarDerivacion(
      BuildContext context, Incidente incidente) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _BottomSheetDerivar(incidente: incidente),
    );

    if (confirmed == true && context.mounted) {
      final ok = await _vm.ejecutarTransicion(
        incidenteId: incidente.id,
        accion: () =>
            context.read<IIncidenteService>().derivar(incidente.id),
      );
      if (ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incidente derivado al CAI más cercano.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sesion = context.watch<SesionViewModel>();

    return ChangeNotifierProvider.value(
      value: _vm,
      child: Scaffold(
        backgroundColor: AppColors.blancoVerde,
        appBar: AppBar(
          backgroundColor: AppColors.negroTexto,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Centro de Comando',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              Text(sesion.nombreMostrar,
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.vpn_key_outlined, color: Colors.white),
              tooltip: 'Generar invitación de agente',
              onPressed: () => _mostrarGenerarInvitacion(context),
            ),
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
          bottom: TabBar(
            controller: _tabs,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: const [
              Tab(text: 'Reportados'),
              Tab(text: 'Delegados'),
            ],
          ),
        ),
        body: Consumer<IncidenteListViewModel>(
          builder: (ctx, vm, _) => TabBarView(
            controller: _tabs,
            children: [
              // Tab 1 — Reportados (CREADO): listado automático real
              IncidenteListBody(
                vm: vm,
                incidentes: vm.incidentes,
                mensajeVacio: 'No hay emergencias pendientes de derivar.',
                iconoVacio: Icons.inbox_outlined,
                buildCard: (i) => IncidenteCard(
                  incidente: i,
                  onTap: () => Navigator.pushNamed(ctx,
                      AppRoutes.detalleIncidente,
                      arguments: {'incidenteId': i.id}),
                  labelAccion:
                      vm.enProceso(i.id) ? 'Derivando...' : 'Derivar a CAI',
                  onAccion: vm.enProceso(i.id)
                      ? null
                      : () => _mostrarDerivacion(ctx, i),
                ),
              ),

              // Tab 2 — Delegados: recarga mismos datos filtrados por estado
              // (los ya derivados no aparecen en el fetchFn de CREADO,
              // por eso usamos incidentesPorEstado para mostrar el historial
              // dentro de los datos ya cargados — que incluye solo CREADO.
              // Para un historial real de Comando se necesitaría otro endpoint.
              // Por ahora mostramos un aviso claro.)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_outlined,
                          size: 56, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'El historial completo de incidentes derivados '
                        'requiere un endpoint adicional en el backend.\n\n'
                        'Usa "Detalle" desde la card antes de derivar para '
                        'ver el estado de un incidente específico.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomSheetDerivar extends StatelessWidget {
  final Incidente incidente;
  const _BottomSheetDerivar({required this.incidente});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.domain_add_outlined, size: 24),
            const SizedBox(width: 10),
            const Text('Derivar a CAI',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context, false)),
          ]),
          const SizedBox(height: 4),
          const Text(
            'El sistema derivará la emergencia al CAI más cercano '
            'usando la ubicación reportada (algoritmo Haversine).',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade300),
            ),
            child: Row(children: [
              Icon(Icons.location_on, color: Colors.blue.shade700),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CAI más cercano (automático)',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(
                      'El sistema calcula el CAI con menor distancia al '
                      'punto de la emergencia.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.check_circle, color: Colors.blue.shade600),
            ]),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.negroTexto,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar derivación',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}