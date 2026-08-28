import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/app_routes.dart';
import '../../core/colores_app.dart';
import '../../data/models/enums/estado_incidente.dart';
import '../../data/models/enums/rol.dart';
import '../../data/models/incidente.dart';
import '../../data/services/incidente_service.dart';
import '../viewmodels/incidente_list_viewmodel.dart';
import '../viewmodels/sesion_viewmodel.dart';
import '../widgets/incidente_card.dart';
import '../widgets/incidente_list_body.dart';
import '../widgets/role_header.dart';

/// Home del Agente de Policía.
///
/// F.2 — Home views por rol + Detalle de Incidente.
///
/// Lista `GET /incidentes/asignados` con acciones por estado:
/// - AGENTE_ASIGNADO  → "Ir en camino"  → PATCH /{id}/en-camino.
/// - AGENTE_EN_CAMINO → "Atender"       → PATCH /{id}/atender.
/// - EN_ATENCION      → "Finalizar"     → PATCH /{id}/evaluar
///                                         + navegar a ReporteHallazgosView.
///
/// Modo prueba (SOLO pruebas piloto, ver `AppConfig.modoPruebaHabilitado`):
/// cuando está activo el switch de la cabecera, "Ir en camino" manda
/// `?simular=true` — el backend reemplaza el GPS real por un recorrido
/// simulado CAI → incidente (ver `SimularRecorridoAgenteService`). El
/// switch solo aparece en builds compilados con
/// `--dart-define=MODO_PRUEBA_HABILITADO=true`; en cualquier otro build
/// (incluida producción) este bloque de UI ni siquiera se construye.
class HomeAgenteView extends StatefulWidget {
  const HomeAgenteView({super.key});

  @override
  State<HomeAgenteView> createState() => _HomeAgenteViewState();
}

class _HomeAgenteViewState extends State<HomeAgenteView> {
  late IncidenteListViewModel _vm;

  /// Estado del switch "Modo prueba". Solo tiene efecto si
  /// `AppConfig.modoPruebaHabilitado` es `true` en este build; de lo
  /// contrario el switch ni se muestra y este valor nunca se usa.
  bool _modoPrueba = false;

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
          accion: () => service.enCamino(
            incidente.id,
            simular: AppConfig.modoPruebaHabilitado && _modoPrueba,
          ),
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
        appBar: RoleHeader(
          rol: Rol.AGENTE,
          titulo: 'Mis asignaciones',
          subtitulo: sesion.nombreMostrar,
        ),
        body: Column(
          children: [
            if (AppConfig.modoPruebaHabilitado) _buildBannerModoPrueba(),
            Expanded(
              child: Consumer<IncidenteListViewModel>(
                builder: (ctx, vm, _) => IncidenteListBody(
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
          ],
        ),
      ),
    );
  }

  /// Banner "Modo prueba" — SOLO pruebas piloto.
  ///
  /// Solo se construye cuando `AppConfig.modoPruebaHabilitado` es `true`
  /// (ver el `if` en `build()`), así que en un build de producción normal
  /// este widget nunca existe — no es solo "invisible", no se compila su
  /// lógica dentro del árbol para ese build.
  ///
  /// Mientras está activo, "Ir en camino" en cualquier incidente de esta
  /// lista dispara la simulación de recorrido en vez de esperar el GPS
  /// real del celular (ver `IncidenteService.enCamino`).
  Widget _buildBannerModoPrueba() {
    return Material(
      color: _modoPrueba
          ? Colors.orange.shade100
          : Colors.grey.shade200,
      child: SwitchListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        secondary: Icon(
          Icons.science_outlined,
          color: _modoPrueba ? Colors.orange.shade800 : Colors.grey.shade600,
        ),
        title: const Text(
          'Modo prueba',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        subtitle: Text(
          _modoPrueba
              ? 'Activo — "Ir en camino" simulará el trayecto del CAI al incidente'
              : 'Desactivado — se usará el GPS real de este celular',
          style: const TextStyle(fontSize: 11),
        ),
        value: _modoPrueba,
        onChanged: (valor) => setState(() => _modoPrueba = valor),
      ),
    );
  }
}