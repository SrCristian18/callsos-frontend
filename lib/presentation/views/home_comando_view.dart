import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_routes.dart';
import '../../core/colores_app.dart';
import '../../data/models/enums/estado_incidente.dart';
import '../../data/models/incidente.dart';
import '../../data/services/incidente_service.dart';
import '../viewmodels/incidente_list_viewmodel.dart';
import '../viewmodels/sesion_viewmodel.dart';
import '../widgets/incidente_card.dart';
import '../widgets/incidente_list_body.dart';

/// Home de Comando.
///
/// F.2 — Home views por rol + Detalle de Incidente.
///
/// Tabs: "Reportados" (CREADO, pendientes de derivar) / "Delegados" (resto).
/// Acción "Derivar a CAI": bottom sheet con opción automática
/// (ver F.0.7 gap 2) → PATCH /{id}/derivar.
///
/// NOTA: el backend no tiene un endpoint exclusivo para Comando que devuelva
/// "todos los incidentes" — se usa misIncidentes() como workaround
/// transitorio (F.0.7). En una versión futura debería existir un
/// GET /incidentes/todos (COMANDO) o similar.
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
    // WORKAROUND (F.0.7 gap 2): no hay endpoint "todos para Comando".
    // Se usa porCai() o misIncidentes() según permisos del JWT.
    // El backend resolverá esto con un endpoint dedicado.
    _vm = IncidenteListViewModel(
      service: service,
      fetchFn: service.porCai,
    );
    _vm.cargar();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _mostrarDerivacion(
      BuildContext context, Incidente incidente) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) =>
          _BottomSheetDerivar(incidente: incidente),
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
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
              Text(sesion.nombrePlaceholder,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () async {
                await sesion.logout();
                if (mounted) {
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
          builder: (ctx, vm, __) => TabBarView(
            controller: _tabs,
            children: [
              // Tab 1 — Reportados (CREADO)
              IncidenteListBody(
                vm: vm,
                incidentes: vm.incidentesPorEstado(
                    [EstadoIncidente.CREADO]),
                mensajeVacio: 'No hay emergencias pendientes de derivar.',
                iconoVacio: Icons.inbox_outlined,
                buildCard: (i) => IncidenteCard(
                  incidente: i,
                  onTap: () => Navigator.pushNamed(ctx,
                      AppRoutes.detalleIncidente,
                      arguments: {'incidenteId': i.id}),
                  labelAccion: vm.enProceso(i.id)
                      ? 'Derivando...'
                      : 'Derivar a CAI',
                  onAccion: vm.enProceso(i.id)
                      ? null
                      : () => _mostrarDerivacion(ctx, i),
                ),
              ),

              // Tab 2 — Delegados (ya derivados)
              IncidenteListBody(
                vm: vm,
                incidentes: vm.incidentesPorEstado([
                  EstadoIncidente.DERIVADO_A_CAI,
                  EstadoIncidente.AGENTE_ASIGNADO,
                  EstadoIncidente.AGENTE_EN_CAMINO,
                  EstadoIncidente.EN_ATENCION,
                  EstadoIncidente.FINALIZADO,
                  EstadoIncidente.CANCELADO,
                ]),
                mensajeVacio: 'No hay incidentes delegados.',
                iconoVacio: Icons.history_outlined,
                buildCard: (i) => IncidenteCard(
                  incidente: i,
                  onTap: () => Navigator.pushNamed(ctx,
                      AppRoutes.detalleIncidente,
                      arguments: {'incidenteId': i.id}),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet de derivación a CAI (opción automática — F.0.7 gap 2).
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
            'El sistema derivará la emergencia al CAI más cercano usando la '
            'ubicación reportada.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),
          // Opción única (F.0.7 gap 2 — deuda de backend)
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
                      'punto de la emergencia (algoritmo Haversine).',
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