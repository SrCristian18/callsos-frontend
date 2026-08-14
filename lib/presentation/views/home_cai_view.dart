import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_routes.dart';
import '../../core/colores_app.dart';
import '../../data/models/agente_disponible.dart';
import '../../data/models/enums/estado_incidente.dart';
import '../../data/models/incidente.dart';
import '../../data/services/api_exception.dart';
import '../../data/services/cai_service.dart';
import '../../data/services/incidente_service.dart';
import '../viewmodels/incidente_list_viewmodel.dart';
import '../viewmodels/sesion_viewmodel.dart';
import '../widgets/incidente_card.dart';
import '../widgets/incidente_list_body.dart';

/// Home del Operador CAI.
///
/// F.2 — Home views por rol + Detalle de Incidente.
///
/// Tabs: "Por Asignar" (DERIVADO_A_CAI) / "Historial" (resto).
/// Acción "Asignar Agente": bottom sheet con opción automática
/// (ver F.0.7 gap 3) → PATCH /{id}/asignar.
class HomeCAIView extends StatefulWidget {
  const HomeCAIView({super.key});

  @override
  State<HomeCAIView> createState() => _HomeCAIViewState();
}

class _HomeCAIViewState extends State<HomeCAIView>
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

  Future<void> _mostrarAsignacionAgente(
      BuildContext context, Incidente incidente) async {
    final sesion = context.read<SesionViewModel>();
    final caiService = context.read<ICaiService>();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      // FIX: sin esto, el bottom sheet queda limitado a una fracción fija
      // y pequeña de la altura de pantalla, SIN scroll — si el contenido
      // (encabezado + descripción + lista de agentes + aviso + botón) no
      // entra ahí, Flutter hace overflow silencioso en producción (franjas
      // amarillas/negras) y, en tests, lanza una excepción real que abortó
      // los 5 tests de este archivo. isScrollControlled: true deja que el
      // sheet crezca hasta el alto real de su contenido (hasta la pantalla
      // completa si hiciera falta), y el SingleChildScrollView de abajo es
      // la red de seguridad para cuando aun así no entre (teclado abierto,
      // pantalla chica, lista de agentes larga).
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _BottomSheetAsignarAgente(
        incidente: incidente,
        caiId: sesion.actorId ?? '',
        caiService: caiService,
      ),
    );

    if (confirmed == true && context.mounted) {
      final ok = await _vm.ejecutarTransicion(
        incidenteId: incidente.id,
        accion: () =>
            context.read<IIncidenteService>().asignar(incidente.id),
      );
      if (ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Agente asignado exitosamente.'),
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
          backgroundColor: Colors.green.shade700,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Panel CAI',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
              Text(sesion.nombreMostrar,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              tooltip: 'Cerrar sesión',
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
              Tab(text: 'Por Asignar'),
              Tab(text: 'Historial'),
            ],
          ),
        ),
        body: Consumer<IncidenteListViewModel>(
          builder: (ctx, vm, __) => TabBarView(
            controller: _tabs,
            children: [
              // Tab 1 — Por asignar (DERIVADO_A_CAI)
              IncidenteListBody(
                vm: vm,
                incidentes: vm.incidentesPorEstado(
                    [EstadoIncidente.DERIVADO_A_CAI]),
                mensajeVacio: 'No hay incidentes pendientes de asignar.',
                iconoVacio: Icons.assignment_outlined,
                buildCard: (i) => IncidenteCard(
                  incidente: i,
                  onTap: () => Navigator.pushNamed(ctx,
                      AppRoutes.detalleIncidente,
                      arguments: {'incidenteId': i.id}),
                  labelAccion: vm.enProceso(i.id)
                      ? 'Asignando...'
                      : 'Asignar Agente',
                  onAccion: vm.enProceso(i.id)
                      ? null
                      : () => _mostrarAsignacionAgente(ctx, i),
                ),
              ),

              // Tab 2 — Historial (todos los demás estados)
              IncidenteListBody(
                vm: vm,
                incidentes: vm.incidentesPorEstado([
                  EstadoIncidente.AGENTE_ASIGNADO,
                  EstadoIncidente.AGENTE_EN_CAMINO,
                  EstadoIncidente.EN_ATENCION,
                  EstadoIncidente.FINALIZADO,
                  EstadoIncidente.CANCELADO,
                ]),
                mensajeVacio: 'El historial está vacío.',
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

/// Bottom sheet de asignación de agente.
///
/// FIX Gap 3 (deuda_backend.md): ahora muestra la lista REAL de agentes
/// disponibles del CAI (antes solo mostraba el mensaje genérico de
/// "asignación automática" sin ningún dato real detrás).
///
/// La asignación en sí SIGUE siendo automática — el backend todavía no
/// expone un endpoint para elegir manualmente un agente específico
/// (ver PATCH /{id}/asignar en IncidenteController). Esta lista es
/// informativa: el operador ve a quién probablemente se le asignará
/// antes de confirmar, y el botón queda deshabilitado si no hay nadie
/// disponible (evita un 422 innecesario contra el backend).
class _BottomSheetAsignarAgente extends StatefulWidget {
  final Incidente incidente;
  final String caiId;
  final ICaiService caiService;

  const _BottomSheetAsignarAgente({
    required this.incidente,
    required this.caiId,
    required this.caiService,
  });

  @override
  State<_BottomSheetAsignarAgente> createState() =>
      _BottomSheetAsignarAgenteState();
}

class _BottomSheetAsignarAgenteState
    extends State<_BottomSheetAsignarAgente> {
  List<AgenteDisponible>? _agentes;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarAgentes();
  }

  Future<void> _cargarAgentes() async {
    try {
      final agentes = await widget.caiService.agentesDisponibles(widget.caiId);
      if (mounted) setState(() => _agentes = agentes);
    } on ApiException catch (e) {
      // No bloqueamos el flujo de asignación si esta consulta informativa
      // falla — el botón de asignación automática sigue funcionando igual
      // que antes de este fix.
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sinAgentes = _agentes != null && _agentes!.isEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.person_add_outlined, size: 24),
            const SizedBox(width: 10),
            const Text('Asignar agente',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cerrar',
                onPressed: () => Navigator.pop(context, false)),
          ]),
          const SizedBox(height: 4),
          const Text(
            'El sistema seleccionará automáticamente el agente disponible '
            'más adecuado dentro de este CAI.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),

          // Lista real de agentes disponibles (informativa).
          if (_agentes == null && _error == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_error != null)
            Text(
              'No se pudo cargar la lista de agentes ($_error). '
              'La asignación automática sigue disponible.',
              style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
            )
          else if (sinAgentes)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.red.shade700),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'No hay agentes disponibles en este CAI en este momento.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ]),
            )
          else
            ..._agentes!.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Icon(Icons.person, size: 18, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Text(a.nombre, style: const TextStyle(fontSize: 13)),
                  ]),
                )),

          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade300),
            ),
            child: Row(children: [
              Icon(Icons.person, color: Colors.green.shade700),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Asignación automática',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(
                      'Se asignará el agente disponible más cercano al incidente.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.check_circle, color: Colors.green.shade600),
            ]),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              // Deshabilitado solo si confirmamos que no hay nadie
              // disponible; si la consulta falló (_error != null) dejamos
              // intentar igual, porque el backend es la fuente de verdad.
              onPressed: sinAgentes
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Confirmar asignación',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
        ),
      ),
    );
  }
}