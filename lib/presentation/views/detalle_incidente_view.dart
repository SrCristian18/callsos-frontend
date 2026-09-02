import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/app_radius.dart';
import '../../core/app_routes.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../core/colores_app.dart';
import '../../data/models/enums/estado_incidente.dart';
import '../../data/models/enums/rol.dart';
import '../../data/models/incidente.dart';
import '../../data/models/tipo_incidente_presentacion.dart';
import '../../data/services/api_exception.dart';
import '../../data/services/incidente_service.dart';
import '../viewmodels/sesion_viewmodel.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_view.dart';
import '../widgets/estado_chip.dart';
import '../widgets/eta_widget.dart';
import '../widgets/loading_view.dart';
import '../widgets/selector_tipo_incidente.dart';
import '../widgets/timeline.dart';

/// Detalle completo de un incidente.
///
/// F.2 — Home views por rol + Detalle de Incidente.
///
/// Recibe `incidenteId` como argumento de ruta y llama
/// `GET /incidentes/{id}`.
///
/// Botones/widgets contextuales según rol + estado:
/// - DENUNCIANTE + AGENTE_EN_CAMINO → tarjeta de ETA (Épica 7, `EtaWidget`) —
///   reemplaza el antiguo botón "Ver agente en mapa" (retirado por P6,
///   Épica 3: el denunciante ya no puede ver el GPS crudo del agente).
/// - DENUNCIANTE dueño + activo      → "Actualizar tipo" (Épica 6) →
///   selector (`selector_tipo_incidente.dart`) → PATCH /{id}/tipo.
/// - AGENTE + (ASIGNADO/EN_CAMINO/EN_ATENCION) → "Compartir mi ubicación"
///   (Épica 7) → TrackingView en modo emisor.
/// - OPERADOR_CAI/COMANDO + agente asignado + (ASIGNADO/EN_CAMINO/EN_ATENCION)
///   → "Ver ubicación del agente" (Épica 7) → TrackingView en modo receptor.
/// - AGENTE + AGENTE_ASIGNADO       → "Ir en camino" → PATCH /{id}/en-camino.
/// - AGENTE + AGENTE_EN_CAMINO      → "Llegué — Atender" → PATCH /{id}/atender.
/// - AGENTE + EN_ATENCION           → "Finalizar" → PATCH /{id}/evaluar + ReporteHallazgos.
/// - Activo + no DENUNCIANTE        → "Cancelar" → PATCH /{id}/cancelar.
/// - DENUNCIANTE + activo            → "Cancelar emergencia".
///
/// EPIC-10 (Design System, auditoría UX/UI) — "Experiencia del Agente":
/// - La acción principal del AGENTE ("Ir en camino" / "Llegué — Iniciar
///   atención" / "Finalizar y reportar hallazgos", una por estado, nunca
///   más de una a la vez) se saca del contenido scrolleable y se fija en
///   un `bottomNavigationBar` — ver [_accionPrincipalAgente] y
///   [_barraAccionPrincipal]. Así queda SIEMPRE visible sin scroll
///   (criterio de terminado de la épica) y, de paso, queda espacialmente
///   separada de "Cancelar emergencia" (que sigue en la lista
///   scrolleable) — dos botones grandes uno pegado al otro es
///   exactamente el escenario de toque accidental que la heurística #5
///   busca evitar.
/// - "Cancelar emergencia" (cualquier rol) ahora pide confirmación
///   ([ConfirmationDialog], mismo componente de EPIC-04) antes de
///   ejecutar — es la acción más irreversible de toda esta vista y
///   antes se disparaba con un solo toque, sin pedir confirmación.
class DetalleIncidenteView extends StatefulWidget {
  const DetalleIncidenteView({super.key});

  @override
  State<DetalleIncidenteView> createState() => _DetalleIncidenteViewState();
}

class _DetalleIncidenteViewState extends State<DetalleIncidenteView>
    with SingleTickerProviderStateMixin {
  Incidente? _incidente;
  bool _isLoading = true;
  String? _error;
  bool _enProceso = false;

  /// EPIC-07 — tab "Detalle" / "Historial". Vive en el State (no
  /// `DefaultTabController`) para que la pestaña elegida sobreviva a los
  /// `setState()` que dispara `_ejecutar()` tras cada acción (ej.
  /// "Ir en camino"): con `DefaultTabController` el widget se
  /// reconstruye completo en cada rebuild del árbol y la selección
  /// vuelve siempre a la pestaña 0.
  late final TabController _tabController =
      TabController(length: 2, vsync: this);

  /// Espejo del mismo switch de `HomeAgenteView` — se muestra (y aplica)
  /// solo si `AppConfig.modoPruebaHabilitado` es `true` en este build.
  /// Ver el bloque "Modo prueba" dentro de `_botonesContextuales`.
  bool _modoPrueba = false;

  late String _incidenteId;

  /// FIX: sin esta guarda, `_cargar()` se disparaba en cada
  /// `didChangeDependencies()` — y ese método NO se llama una sola vez.
  /// Flutter lo vuelve a invocar cada vez que cambia una dependencia de
  /// InheritedWidget, y `ModalRoute.of(context)` es una de esas
  /// dependencias: cuando esta vista deja de ser la ruta activa (ej. se
  /// abre `mostrarSelectorTipoIncidente`, que internamente hace
  /// `Navigator.push` de su propia ruta) y cuando vuelve a serlo (se
  /// cierra el selector), `isCurrent` cambia en ambos sentidos y dispara
  /// `didChangeDependencies()` de nuevo — 2 disparos extra por cada
  /// apertura/cierre de CUALQUIER modal sobre esta vista, sin relación
  /// con el argumento de ruta (`incidenteId`), que no cambió.
  /// `_incidenteId` sí necesita leerse de `ModalRoute.of(context)` en
  /// `didChangeDependencies()` (no en `initState()`, porque ahí el
  /// contexto todavía no tiene acceso a los InheritedWidgets de rutas),
  /// pero la CARGA (`_cargar()`) solo debe dispararse la primera vez.
  bool _yaCargado = false;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_yaCargado) return;
    _yaCargado = true;

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _incidenteId = args?['incidenteId'] as String? ?? '';
    if (_incidenteId.isNotEmpty) _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final inc = await context
          .read<IIncidenteService>()
          .consultar(_incidenteId);
      if (mounted) setState(() => _incidente = inc);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo cargar el incidente.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _ejecutar(Future<void> Function() accion,
      {String? mensajeExito, String? rutaPostExito, Map<String, dynamic>? args}) async {
    setState(() => _enProceso = true);
    try {
      await accion();
      if (mensajeExito != null && mounted) {
        AppSnackBar.exito(context, mensajeExito);
      }
      if (rutaPostExito != null && mounted) {
        Navigator.pushNamed(context, rutaPostExito, arguments: args);
      } else {
        await _cargar(); // refrescar el detalle
      }
    } on ApiException catch (e) {
      if (mounted) {
        AppSnackBar.error(context, e.message);
      }
    } finally {
      if (mounted) setState(() => _enProceso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rol = context.read<SesionViewModel>().rol;
    final service = context.read<IIncidenteService>();

    return Scaffold(
      backgroundColor: AppColors.blancoVerde,
      appBar: AppBar(
        backgroundColor: AppColors.verdeOscuro,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          tooltip: 'Volver',
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _incidente != null
              ? (catalogoTipos[_incidente!.tipo]?.titulo ?? 'Incidente')
              : 'Detalle',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Actualizar',
            onPressed: _isLoading ? null : _cargar,
          ),
        ],
        // EPIC-07: la pestaña "Historial" solo tiene sentido una vez que
        // el incidente cargó (necesita `inc.id`) — mientras está en
        // loading/error no se muestra TabBar, así el usuario no ve una
        // pestaña que llevaría a un widget sin datos que mostrar todavía.
        bottom: _incidente != null
            ? TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: const [
                  Tab(text: 'Detalle', icon: Icon(Icons.info_outline)),
                  Tab(text: 'Historial', icon: Icon(Icons.history)),
                ],
              )
            : null,
      ),
      body: _buildBody(rol, service),
      // EPIC-10: acción principal del AGENTE fijada fuera del área
      // scrolleable — ver el comentario de clase. `null` en cualquier
      // otro caso (Scaffold lo maneja bien: sin bottomNavigationBar).
      bottomNavigationBar: _incidente != null
          ? _barraAccionPrincipal(_incidente!, rol, service)
          : null,
    );
  }

  Widget _buildBody(Rol? rol, IIncidenteService service) {
    // EPIC-09 (Design System, auditoría UX/UI) — checklist §18
    // (loading/success/error/empty), igual que `IncidenteListBody`: los
    // 3 estados sin datos pasan a usar los componentes de EPIC-03 en vez
    // de bloques hechos a mano, mismo resultado visible de antes.
    if (_isLoading) {
      return const LoadingView(mensaje: 'Cargando incidente...');
    }

    if (_error != null) {
      // `icon` explícito: a diferencia de `IncidenteListBody` (donde el
      // error casi siempre es de conectividad, de ahí el ícono por
      // defecto de `ErrorView`), acá `_error` también puede venir de un
      // 404/403 (`ApiException` de negocio, no de red) — `error_outline`
      // es correcto para ambos casos, `wifi_off_outlined` no lo sería
      // para el primero.
      return ErrorView(
        message: _error!,
        icon: Icons.error_outline,
        onRetry: _cargar,
      );
    }

    if (_incidente == null) {
      // Caso borde: ni loading, ni error, ni incidente — no debería
      // darse en el flujo normal (la carga siempre deja el ViewModel en
      // uno de los otros 3 estados), pero antes de EPIC-09 esta rama
      // devolvía un `SizedBox()` — una pantalla en blanco sin ninguna
      // explicación si alguna vez se llegara a pisar. `EmptyState` le da
      // a ese caso borde el mismo tratamiento que el resto del checklist.
      return const EmptyState(
        icon: Icons.help_outline,
        message: 'No se encontró información de este incidente.',
      );
    }

    final inc = _incidente!;
    final sesion = context.read<SesionViewModel>();
    final pres = catalogoTipos[inc.tipo];

    // EPIC-07: tab "Detalle" (contenido ya existente, sin cambios) +
    // tab "Historial" (nuevo — `Timeline`, ver `timeline.dart`). El
    // endpoint de auditoría ya viene filtrado por actor en el backend
    // (`AuditoriaController`), así que `Timeline` no necesita saber el
    // rol de la sesión: cada actor ve exactamente lo que el servidor le
    // autoriza, sin lógica adicional acá.
    return TabBarView(
      controller: _tabController,
      children: [
        _buildDetalle(inc, rol, service, sesion, pres),
        Timeline(incidenteId: inc.id),
      ],
    );
  }

  Widget _buildDetalle(Incidente inc, Rol? rol, IIncidenteService service,
      SesionViewModel sesion, TipoIncidentePresentacion? pres) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card principal ──────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppRadius.borderLg,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tipo + estado
                Row(children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: pres?.color ?? Colors.grey,
                      borderRadius: AppRadius.borderMd,
                    ),
                    child: Icon(pres?.icono ?? Icons.warning,
                        color: Colors.white, size: 26),
                  ),
                  AppSpacing.gapMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // EPIC-09: mismo token que el título de
                        // `IncidenteCard` — el nombre del tipo de
                        // incidente es la MISMA pieza de información en
                        // ambas vistas, así que debe verse igual de
                        // prominente en las dos.
                        Text(
                          pres?.titulo ?? inc.tipo.name,
                          style: AppTextStyles.tituloMediano,
                        ),
                        AppSpacing.gapXs,
                        EstadoChip(estado: inc.estado),
                      ],
                    ),
                  ),
                ]),

                if (inc.descripcion.isNotEmpty) ...[
                  AppSpacing.gapLg,
                  Text('Descripción',
                      style: AppTextStyles.cuerpo
                          .copyWith(fontWeight: FontWeight.w600)),
                  AppSpacing.gapXs,
                  Text(inc.descripcion,
                      style: AppTextStyles.cuerpo
                          .copyWith(color: Colors.grey.shade700)),
                ],

                const Divider(height: 28),

                // Metadatos
                _fila(Icons.calendar_today_outlined, 'Fecha y hora',
                    _fecha(inc.fechaHora)),
                AppSpacing.gapSm,
                _fila(Icons.location_on_outlined, 'Coordenadas GPS',
                    '${inc.latitud.toStringAsFixed(5)}, '
                        '${inc.longitud.toStringAsFixed(5)}'),
                if (inc.nombreCAI != null) ...[
                  AppSpacing.gapSm,
                  _fila(Icons.domain_outlined, 'CAI asignado',
                      inc.nombreCAI!),
                ],
              ],
            ),
          ),

          AppSpacing.gapXl,

          // ── Widget de ETA (Épica 7) ──────────────────────────────────
          // Solo para el DENUNCIANTE, y solo mientras hay un agente en
          // camino — antes de eso no hay ETA que calcular, y en estados
          // posteriores (EN_ATENCION+) el agente ya llegó.
          if (rol == Rol.DENUNCIANTE &&
              inc.estado == EstadoIncidente.AGENTE_EN_CAMINO) ...[
            EtaWidget(incidenteId: inc.id),
            AppSpacing.gapXl,
          ],

          // ── Botones contextuales ────────────────────────────────────
          // EPIC-09: mismo LoadingView del checklist §18 en vez del
          // `CircularProgressIndicator` suelto de antes — este es el
          // sub-estado "procesando" de una transición (Ir en camino,
          // Cancelar, etc.), no loading de PÁGINA completa, por eso lleva
          // mensaje propio en vez de reusar "Cargando incidente...".
          if (!_enProceso) ..._botonesContextuales(inc, rol, service, sesion.actorId)
          else
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: LoadingView(mensaje: 'Procesando...'),
            ),
        ],
      ),
    );
  }

  List<Widget> _botonesContextuales(
      Incidente inc, Rol? rol, IIncidenteService service, String? actorId) {
    final botones = <Widget>[];

    // Épica 7: tracking en tiempo real — ya NO para DENUNCIANTE (ver
    // EtaWidget más arriba, que lo reemplaza). Se muestra mientras hay
    // (o puede haber en breve) un agente moviéndose: desde que se le
    // asigna hasta que empieza la atención en el sitio.
    const estadosConTracking = {
      EstadoIncidente.AGENTE_ASIGNADO,
      EstadoIncidente.AGENTE_EN_CAMINO,
      EstadoIncidente.EN_ATENCION,
    };

    // AGENTE → comparte su propia posición (modo emisor).
    if (rol == Rol.AGENTE && estadosConTracking.contains(inc.estado)) {
      botones.add(_boton(
        label: '📍 Compartir mi ubicación',
        color: AppColors.verdeOscuro,
        onPressed: () => Navigator.pushNamed(
          context,
          AppRoutes.tracking,
          arguments: {'incidenteId': inc.id, 'agenteId': actorId},
        ),
      ));
    }

    // OPERADOR_CAI / COMANDO → ve la posición del agente asignado (modo
    // receptor). Requiere que ya haya una asignación activa
    // (inc.agenteId != null) — antes de AGENTE_ASIGNADO no hay a quién
    // seguir todavía.
    if ((rol == Rol.OPERADOR_CAI || rol == Rol.COMANDO) &&
        inc.agenteId != null &&
        estadosConTracking.contains(inc.estado)) {
      botones.add(_boton(
        label: '📍 Ver ubicación del agente',
        color: AppColors.verdeOscuro,
        onPressed: () => Navigator.pushNamed(
          context,
          AppRoutes.tracking,
          arguments: {'incidenteId': inc.id, 'agenteId': inc.agenteId},
        ),
      ));
    }

    // DENUNCIANTE dueño + incidente activo → actualizar tipo (Épica 6).
    // Ownership explícita (denuncianteId == actorId de la sesión), no solo
    // el rol: esta vista puede abrirse con el id de CUALQUIER incidente
    // (llega como argumento de ruta), y el backend además rechaza con 403
    // a cualquier denunciante que no sea el dueño — este chequeo en la UI
    // evita mostrar un botón que solo fallaría al confirmarlo.
    if (rol == Rol.DENUNCIANTE &&
        inc.denuncianteId == actorId &&
        inc.estaActivo) {
      if (botones.isNotEmpty) botones.add(const SizedBox(height: 10));
      botones.add(_boton(
        label: '✏️ Actualizar tipo de incidente',
        color: Colors.deepPurple,
        outlined: true,
        onPressed: () => _actualizarTipo(inc, service),
      ));
    }

    // EPIC-10: "Modo prueba" (SOLO pruebas piloto) sigue viviendo en la
    // lista scrolleable — es una preferencia auxiliar, no la acción
    // principal, así que no tiene por qué competir por el espacio fijo
    // del `bottomNavigationBar` (ver [_accionPrincipalAgente]). Se
    // muestra en el mismo estado en el que antes vivía pegado a "Ir en
    // camino" (AGENTE_ASIGNADO) para que sea visible ANTES de que el
    // agente dispare esa acción desde la barra inferior.
    if (rol == Rol.AGENTE &&
        inc.estado == EstadoIncidente.AGENTE_ASIGNADO &&
        AppConfig.modoPruebaHabilitado) {
      if (botones.isNotEmpty) botones.add(const SizedBox(height: 10));
      botones.add(_switchModoPrueba());
    }

    // Cancelar — cualquier estado activo.
    //
    // EPIC-10 (criterio "riesgo de toque accidental" / heurística #5):
    // es la acción más irreversible de esta lista y antes se ejecutaba
    // con un solo toque. Ahora pide confirmación explícita — mismo
    // componente que ya usan el logout (EPIC-08) y, desde esta misma
    // épica, "Enviar reporte" en `reporte_hallazgos_view.dart`.
    if (inc.estaActivo) {
      if (botones.isNotEmpty) botones.add(const SizedBox(height: 10));
      botones.add(_boton(
        label: 'Cancelar emergencia',
        color: Colors.red,
        outlined: true,
        onPressed: () => _confirmarYCancelar(inc, service),
      ));
    }

    return botones;
  }

  Future<void> _confirmarYCancelar(
      Incidente inc, IIncidenteService service) async {
    final confirmado = await ConfirmationDialog.show(
      context,
      title: '¿Cancelar esta emergencia?',
      message: 'El incidente va a quedar CANCELADO. Esta acción no se '
          'puede deshacer.',
      confirmText: 'Sí, cancelar',
      isDangerous: true,
    );
    if (!confirmado || !mounted) return;

    await _ejecutar(
      () => service.cancelar(inc.id),
      mensajeExito: 'Emergencia cancelada.',
    );
  }

  /// EPIC-10 — la acción principal del AGENTE para el estado actual del
  /// incidente (una sola a la vez, nunca simultánea con otra: los 3
  /// estados son mutuamente excluyentes). `null` si el rol no es AGENTE
  /// o si el estado actual no tiene una acción principal asociada (ej.
  /// CREADO, DERIVADO_A_CAI, FINALIZADO, CANCELADO).
  ///
  /// Se renderiza en [_barraAccionPrincipal], FUERA del
  /// `SingleChildScrollView` de [_buildDetalle] — ver el comentario de
  /// clase.
  Widget? _accionPrincipalAgente(
      Incidente inc, Rol? rol, IIncidenteService service) {
    if (rol != Rol.AGENTE) return null;

    switch (inc.estado) {
      case EstadoIncidente.AGENTE_ASIGNADO:
        return _boton(
          label: '🚓 Ir en camino',
          color: Colors.blue.shade700,
          cargando: _enProceso,
          onPressed: () => _ejecutar(
            () => service.enCamino(
              inc.id,
              simular: AppConfig.modoPruebaHabilitado && _modoPrueba,
            ),
            mensajeExito: _modoPrueba && AppConfig.modoPruebaHabilitado
                ? 'Marcaste que vas en camino (simulado).'
                : 'Marcaste que vas en camino.',
          ),
        );

      case EstadoIncidente.AGENTE_EN_CAMINO:
        return _boton(
          label: '🏠 Llegué — Iniciar atención',
          color: Colors.indigo,
          cargando: _enProceso,
          onPressed: () => _ejecutar(
            () => service.atender(inc.id),
            mensajeExito: 'Atención iniciada.',
          ),
        );

      case EstadoIncidente.EN_ATENCION:
        return _boton(
          label: '✅ Finalizar y reportar hallazgos',
          color: Colors.green.shade700,
          cargando: _enProceso,
          onPressed: () => Navigator.pushNamed(
            context,
            AppRoutes.reporteHallazgos,
            arguments: {'incidenteId': inc.id},
            // F.4: NO llamar evaluar() aquí — POST /reportes/hallazgos
            // ya finaliza el incidente internamente (CrearReporteHallazgosService).
          ),
        );

      default:
        return null;
    }
  }

  /// Barra inferior fija con la acción principal del AGENTE — `null`
  /// (sin `bottomNavigationBar`) para cualquier otro rol o estado sin
  /// acción principal, ver [_accionPrincipalAgente].
  Widget? _barraAccionPrincipal(
      Incidente inc, Rol? rol, IIncidenteService service) {
    final accion = _accionPrincipalAgente(inc, rol, service);
    if (accion == null) return null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.md),
          child: accion,
        ),
      ),
    );
  }

  /// Épica 6: abre el selector de tipo y, si el denunciante elige uno,
  /// ejecuta la actualización (elegir una opción del selector ES el
  /// gesto de confirmación — ver `selector_tipo_incidente.dart`).
  ///
  /// Reutiliza `_ejecutar` (igual que el resto de acciones de esta
  /// vista): maneja `_enProceso`, `ApiException`, y refresca `_incidente`
  /// tras el éxito para que la card principal muestre el tipo nuevo.
  Future<void> _actualizarTipo(Incidente inc, IIncidenteService service) async {
    final nuevoTipo = await mostrarSelectorTipoIncidente(
      context,
      tipoActual: inc.tipo,
    );
    if (nuevoTipo == null || !mounted) return;

    await _ejecutar(
      () => service.actualizarTipo(inc.id, nuevoTipo),
      mensajeExito: 'Tipo de incidente actualizado.',
    );
  }

  /// Switch "Modo prueba" — SOLO pruebas piloto (ver `AppConfig.modoPruebaHabilitado`).
  /// Consistente con el mismo control en `HomeAgenteView`.
  Widget _switchModoPrueba() {
    return Container(
      decoration: BoxDecoration(
        color: _modoPrueba ? Colors.orange.shade100 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        dense: true,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
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
              ? 'Simulará el trayecto del CAI al incidente'
              : 'Se usará el GPS real de este celular',
          style: const TextStyle(fontSize: 11),
        ),
        value: _modoPrueba,
        onChanged: (valor) => setState(() => _modoPrueba = valor),
      ),
    );
  }

  Widget _boton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
    bool outlined = false,
    // EPIC-10: usado por [_accionPrincipalAgente] — la barra inferior
    // fija no tiene un LoadingView propio como el resto de la lista
    // scrolleable (ver `_enProceso` en `_buildDetalle`), así que el
    // propio botón necesita poder mostrar "esto está en curso" sin
    // desaparecer ni moverse de lugar.
    bool cargando = false,
  }) {
    final shape = RoundedRectangleBorder(borderRadius: AppRadius.borderMd);
    final child = cargando
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
          )
        : Text(label, style: const TextStyle(fontWeight: FontWeight.bold));

    return SizedBox(
      width: double.infinity,
      child: outlined
          ? OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: color),
                foregroundColor: color,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: shape,
              ),
              onPressed: cargando ? null : onPressed,
              child: child,
            )
          : ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: shape,
              ),
              onPressed: cargando ? null : onPressed,
              child: child,
            ),
    );
  }

  Widget _fila(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade500),
        AppSpacing.gapSm,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: AppTextStyles.etiqueta.copyWith(color: Colors.grey.shade500)),
              Text(value, style: AppTextStyles.cuerpo),
            ],
          ),
        ),
      ],
    );
  }

  String _fecha(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}  $h:$min';
  }
}