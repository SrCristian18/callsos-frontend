import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_routes.dart';
import '../../core/colores_app.dart';
import '../../data/models/agente_disponible.dart';
import '../../data/models/enums/estado_incidente.dart';
import '../../data/models/enums/rol.dart';
import '../../data/models/incidente.dart';
import '../../data/services/api_exception.dart';
import '../../data/services/cai_service.dart';
import '../../data/services/incidente_service.dart';
import '../viewmodels/incidente_list_viewmodel.dart';
import '../viewmodels/sesion_viewmodel.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/incidente_card.dart';
import '../widgets/role_header.dart';
import '../widgets/incidente_list_body.dart';

/// Home del Operador CAI.
///
/// F.2 — Home views por rol + Detalle de Incidente.
///
/// Tabs: "Por Asignar" (DERIVADO_A_CAI) / "Historial" (resto).
/// Acción "Asignar Agente": bottom sheet con opción automática
/// (ver F.0.7 gap 3) → PATCH /{id}/asignar.
///
/// EPIC-11 (Design System, auditoría UX/UI) — "Experiencia del Operador
/// CAI": objetivo "priorizar información operacional — qué está por
/// asignar vs. qué ya se movió". Antes ambos tabs eran texto plano
/// idéntico entre sí; ahora "Por Asignar" lleva un ícono de alerta +
/// badge numérico en vivo con el conteo de pendientes (ver
/// [_tabConBadge]/[_BadgeContador]) — el operador ve de un vistazo,
/// SIN entrar al tab, si hay algo esperando su atención. "Historial" no
/// lleva badge a propósito: nada ahí requiere ya una acción suya.
///
/// El acceso a auditoría desde el detalle (otro criterio de esta
/// épica) ya estaba resuelto de forma genérica por EPIC-07 — la pestaña
/// "Historial" de `DetalleIncidenteView` es igual de accesible para
/// OPERADOR_CAI que para cualquier otro rol, sin nada específico que
/// agregar acá.
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
        AppSnackBar.exito(context, 'Agente asignado exitosamente.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sesion = context.watch<SesionViewModel>();

    return ChangeNotifierProvider.value(
      value: _vm,
      // EPIC-11 — "Por Asignar" necesita el CONTEO de pendientes ya en
      // el TabBar (dentro del AppBar), no solo dentro del body. Un
      // `Consumer<IncidenteListViewModel>` alrededor del `body` (como
      // antes) no alcanza para eso: el AppBar se arma en el MISMO
      // `build()`, afuera de ese Consumer. `ListenableBuilder` envuelve
      // el Scaffold entero para que AMBOS (TabBar con badge + body)
      // se reconstruyan juntos cuando `_vm` notifica — mismo
      // ChangeNotifier de siempre, solo se mueve el punto de escucha.
      child: ListenableBuilder(
        listenable: _vm,
        builder: (ctx, _) {
          // Objetivo de la épica: "priorizar información operacional —
          // qué está por asignar vs. qué ya se movió". El conteo en
          // vivo en la pestaña es la señal más directa de "esto
          // necesita tu atención AHORA" (heurística #1 — visibilidad
          // del estado del sistema) sin tener que entrar al tab para
          // enterarse de cuántos hay.
          final pendientes =
              _vm.incidentesPorEstado([EstadoIncidente.DERIVADO_A_CAI]).length;

          return Scaffold(
            backgroundColor: AppColors.blancoVerde,
            appBar: RoleHeader(
              rol: Rol.OPERADOR_CAI,
              titulo: 'Panel CAI',
              subtitulo: sesion.nombreMostrar,
              bottom: TabBar(
                controller: _tabs,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                // EPIC-11 — distinción visual clara entre tabs: íconos
                // distintos (reloj/alerta de "pendiente" vs. reloj de
                // "historial") + badge numérico en "Por Asignar" — lo
                // que ya se movió (Historial) no necesita contador,
                // ya no requiere ninguna acción del operador.
                tabs: [
                  _tabConBadge(
                    icono: Icons.assignment_late_outlined,
                    etiqueta: 'Por Asignar',
                    contador: pendientes,
                  ),
                  _tabConBadge(
                    icono: Icons.history_outlined,
                    etiqueta: 'Historial',
                  ),
                ],
              ),
            ),
            body: TabBarView(
              controller: _tabs,
              children: [
                // Tab 1 — Por asignar (DERIVADO_A_CAI)
                IncidenteListBody(
                  vm: _vm,
                  incidentes: _vm
                      .incidentesPorEstado([EstadoIncidente.DERIVADO_A_CAI]),
                  mensajeVacio: 'No hay incidentes pendientes de asignar.',
                  iconoVacio: Icons.assignment_outlined,
                  buildCard: (i) => IncidenteCard(
                    incidente: i,
                    onTap: () => Navigator.pushNamed(ctx,
                        AppRoutes.detalleIncidente,
                        arguments: {'incidenteId': i.id}),
                    labelAccion: _vm.enProceso(i.id)
                        ? 'Asignando...'
                        : 'Asignar Agente',
                    onAccion: _vm.enProceso(i.id)
                        ? null
                        : () => _mostrarAsignacionAgente(ctx, i),
                  ),
                ),

                // Tab 2 — Historial (todos los demás estados)
                IncidenteListBody(
                  vm: _vm,
                  incidentes: _vm.incidentesPorEstado([
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
          );
        },
      ),
    );
  }

  /// Tab con ícono + etiqueta y, opcionalmente, un badge numérico —
  /// EPIC-11: reemplaza los `Tab(text: ...)` planos de antes, que se
  /// veían idénticos entre sí sin importar cuántos incidentes tuviera
  /// cada uno esperando.
  ///
  /// `Tab(child: ...)` (en vez de `text:`/`icon:` por separado) es el
  /// patrón soportado por Flutter para contenido de tab custom — así
  /// ambas pestañas comparten el mismo layout (ícono + texto en una
  /// sola línea), en vez de que una tenga el layout de dos líneas
  /// default (`icon` arriba, `text` abajo) y la otra no.
  ///
  /// FIX: en pantallas angostas (375px — Bloque 4, Épica 8), 2 tabs de
  /// ancho igual dejan ~180px por tab; ícono + "Por Asignar" + badge no
  /// entraban ahí y producían un `RenderFlex overflowed` real (lo
  /// disparaba CUALQUIER test que corriera a ese tamaño, no solo los
  /// que prueban el TabBar — un `RenderFlex overflowed` durante el
  /// build inicial cuenta como excepción no capturada para toda la
  /// pantalla). `FittedBox(fit: BoxFit.scaleDown)` es la salvaguarda:
  /// si el contenido entra, se ve igual que antes; si no entra, se
  /// achica hasta entrar — nunca desborda, sin importar cuán angosta
  /// sea la pantalla.
  Widget _tabConBadge({
    required IconData icono,
    required String etiqueta,
    int? contador,
  }) {
    return Tab(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 18),
            const SizedBox(width: 6),
            Text(etiqueta),
            if (contador != null && contador > 0) ...[
              const SizedBox(width: 6),
              _BadgeContador(contador),
            ],
          ],
        ),
      ),
    );
  }
}

/// Badge numérico — EPIC-11. Color `AppColors.warning` (naranja,
/// EPIC-01): estos son incidentes que YA necesitan una acción del
/// operador ("por asignar"), a diferencia del contenido de "Historial"
/// (ya resuelto/en curso en otro estado), que no lleva badge.
class _BadgeContador extends StatelessWidget {
  final int contador;
  const _BadgeContador(this.contador);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      constraints: const BoxConstraints(minWidth: 20),
      decoration: BoxDecoration(
        color: AppColors.warning,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$contador',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
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
            const Flexible(
              child: Text('Asignar agente',
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
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
                    // FIX (Bloque 4, Épica 8): sin Expanded, un nombre de
                    // agente largo desborda el Row horizontalmente — el
                    // SingleChildScrollView del sheet solo protege el eje
                    // vertical. Con Expanded + ellipsis, un nombre largo se
                    // trunca en vez de romper el layout.
                    Expanded(
                      child: Text(
                        a.nombre,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
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