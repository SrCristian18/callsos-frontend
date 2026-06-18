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

/// Home del Agente de Policía.
///
/// F.2 — Home views por rol + Detalle de Incidente.
///
/// Lista `GET /incidentes/asignados` con acciones por estado:
/// - AGENTE_ASIGNADO  → "Ir en camino"  → PATCH /{id}/en-camino.
/// - AGENTE_EN_CAMINO → "Atender"       → PATCH /{id}/atender.
/// - EN_ATENCION      → "Finalizar"     → PATCH /{id}/evaluar
///                                         + navegar a ReporteHallazgosView.
class HomeAgenteView extends StatefulWidget {
  const HomeAgenteView({super.key});

  @override
  State<HomeAgenteView> createState() => _HomeAgenteViewState();
}

class _HomeAgenteViewState extends State<HomeAgenteView> {
  late IncidenteListViewModel _vm;

  @override
  void initState() {
    super.initState();
    final service = context.read<IIncidenteService>();
    _vm = IncidenteListViewModel(
      service: service,
      fetchFn: service.asignados,
    );
    _vm.cargar();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  String? _labelAccion(Incidente i) {
    switch (i.estado) {
      case EstadoIncidente.AGENTE_ASIGNADO:
        return 'Ir en camino';
      case EstadoIncidente.AGENTE_EN_CAMINO:
        return 'Llegué — Atender';
      case EstadoIncidente.EN_ATENCION:
        return 'Finalizar y reportar';
      default:
        return null;
    }
  }

  Future<void> _ejecutarAccion(
      BuildContext context, Incidente incidente) async {
    final service = context.read<IIncidenteService>();

    switch (incidente.estado) {
      case EstadoIncidente.AGENTE_ASIGNADO:
        await _vm.ejecutarTransicion(
          incidenteId: incidente.id,
          accion: () => service.enCamino(incidente.id),
        );

      case EstadoIncidente.AGENTE_EN_CAMINO:
        await _vm.ejecutarTransicion(
          incidenteId: incidente.id,
          accion: () => service.atender(incidente.id),
        );

      case EstadoIncidente.EN_ATENCION:
        // F.4 — NO llamar evaluar() aquí: CrearReporteHallazgosService
        // (POST /reportes/hallazgos) ya finaliza el incidente internamente.
        // Llamar evaluar() antes causaría 422 (incidente ya FINALIZADO).
        if (context.mounted) {
          Navigator.pushNamed(
            context,
            AppRoutes.reporteHallazgos,
            arguments: {'incidenteId': incidente.id},
          );
        }

      default:
        break;
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
              const Text('Mis asignaciones',
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
        ),
        body: Consumer<IncidenteListViewModel>(
          builder: (ctx, vm, __) => IncidenteListBody(
            vm: vm,
            incidentes: vm.incidentes,
            mensajeVacio: 'No tienes incidentes asignados.',
            iconoVacio: Icons.local_police_outlined,
            buildCard: (incidente) => IncidenteCard(
              incidente: incidente,
              onTap: () => Navigator.pushNamed(
                ctx,
                AppRoutes.detalleIncidente,
                arguments: {'incidenteId': incidente.id},
              ),
              labelAccion: vm.enProceso(incidente.id)
                  ? 'Procesando...'
                  : _labelAccion(incidente),
              onAccion: _labelAccion(incidente) != null &&
                      !vm.enProceso(incidente.id)
                  ? () => _ejecutarAccion(ctx, incidente)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}