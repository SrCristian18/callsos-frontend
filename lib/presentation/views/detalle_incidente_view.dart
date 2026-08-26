import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/app_routes.dart';
import '../../core/colores_app.dart';
import '../../data/models/enums/estado_incidente.dart';
import '../../data/models/enums/rol.dart';
import '../../data/models/incidente.dart';
import '../../data/models/tipo_incidente_presentacion.dart';
import '../../data/services/api_exception.dart';
import '../../data/services/incidente_service.dart';
import '../viewmodels/sesion_viewmodel.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/estado_chip.dart';
import '../widgets/eta_widget.dart';
import '../widgets/selector_tipo_incidente.dart';

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
class DetalleIncidenteView extends StatefulWidget {
  const DetalleIncidenteView({super.key});

  @override
  State<DetalleIncidenteView> createState() => _DetalleIncidenteViewState();
}

class _DetalleIncidenteViewState extends State<DetalleIncidenteView> {
  Incidente? _incidente;
  bool _isLoading = true;
  String? _error;
  bool _enProceso = false;

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
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.verdeOscuro));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 52, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 14)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.verdeOscuro,
                    foregroundColor: Colors.white),
                onPressed: _cargar,
              ),
            ],
          ),
        ),
      );
    }

    if (_incidente == null) return const SizedBox();

    final inc = _incidente!;
    final sesion = context.read<SesionViewModel>();
    final rol = sesion.rol;
    final service = context.read<IIncidenteService>();
    final pres = catalogoTipos[inc.tipo];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card principal ──────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
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
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(pres?.icono ?? Icons.warning,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pres?.titulo ?? inc.tipo.name,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.negroTexto),
                        ),
                        const SizedBox(height: 4),
                        EstadoChip(estado: inc.estado),
                      ],
                    ),
                  ),
                ]),

                if (inc.descripcion.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Descripción',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.negroTexto)),
                  const SizedBox(height: 4),
                  Text(inc.descripcion,
                      style: TextStyle(
                          color: Colors.grey.shade700, fontSize: 14)),
                ],

                const Divider(height: 28),

                // Metadatos
                _fila(Icons.calendar_today_outlined, 'Fecha y hora',
                    _fecha(inc.fechaHora)),
                const SizedBox(height: 10),
                _fila(Icons.location_on_outlined, 'Coordenadas GPS',
                    '${inc.latitud.toStringAsFixed(5)}, '
                        '${inc.longitud.toStringAsFixed(5)}'),
                if (inc.nombreCAI != null) ...[
                  const SizedBox(height: 10),
                  _fila(Icons.domain_outlined, 'CAI asignado',
                      inc.nombreCAI!),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Widget de ETA (Épica 7) ──────────────────────────────────
          // Solo para el DENUNCIANTE, y solo mientras hay un agente en
          // camino — antes de eso no hay ETA que calcular, y en estados
          // posteriores (EN_ATENCION+) el agente ya llegó.
          if (rol == Rol.DENUNCIANTE &&
              inc.estado == EstadoIncidente.AGENTE_EN_CAMINO) ...[
            EtaWidget(incidenteId: inc.id),
            const SizedBox(height: 20),
          ],

          // ── Botones contextuales ────────────────────────────────────
          if (!_enProceso) ..._botonesContextuales(inc, rol, service, sesion.actorId)
          else
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(
                    color: AppColors.verdeOscuro),
              ),
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

    // AGENTE + AGENTE_ASIGNADO → en camino
    if (rol == Rol.AGENTE &&
        inc.estado == EstadoIncidente.AGENTE_ASIGNADO) {
      // FIX Épica 7: sin esta guarda, "Compartir mi ubicación" (arriba)
      // y "Ir en camino" quedaban pegados sin espacio cuando ambos
      // aplican a la vez (mismo estado AGENTE_ASIGNADO para AGENTE).
      if (botones.isNotEmpty) botones.add(const SizedBox(height: 10));

      // Modo prueba (SOLO pruebas piloto): el switch solo se agrega a la
      // lista de widgets si este build tiene el flag encendido — en
      // producción este bloque nunca se construye.
      if (AppConfig.modoPruebaHabilitado) {
        botones.add(_switchModoPrueba());
        botones.add(const SizedBox(height: 6));
      }

      botones.add(_boton(
        label: '🚓 Ir en camino',
        color: Colors.blue.shade700,
        onPressed: () => _ejecutar(
          () => service.enCamino(
            inc.id,
            simular: AppConfig.modoPruebaHabilitado && _modoPrueba,
          ),
          mensajeExito: _modoPrueba && AppConfig.modoPruebaHabilitado
              ? 'Marcaste que vas en camino (simulado).'
              : 'Marcaste que vas en camino.',
        ),
      ));
    }

    // AGENTE + AGENTE_EN_CAMINO → atender
    if (rol == Rol.AGENTE &&
        inc.estado == EstadoIncidente.AGENTE_EN_CAMINO) {
      // FIX Épica 7: misma razón que arriba — "Compartir mi ubicación"
      // también aplica en AGENTE_EN_CAMINO.
      if (botones.isNotEmpty) botones.add(const SizedBox(height: 10));
      botones.add(_boton(
        label: '🏠 Llegué — Iniciar atención',
        color: Colors.indigo,
        onPressed: () => _ejecutar(
          () => service.atender(inc.id),
          mensajeExito: 'Atención iniciada.',
        ),
      ));
    }

    // AGENTE + EN_ATENCION → reporte de hallazgos (sin evaluar() previo)
    if (rol == Rol.AGENTE &&
        inc.estado == EstadoIncidente.EN_ATENCION) {
      // FIX Épica 7: misma razón que arriba — "Compartir mi ubicación"
      // también aplica en EN_ATENCION.
      if (botones.isNotEmpty) botones.add(const SizedBox(height: 10));
      botones.add(_boton(
        label: '✅ Finalizar y reportar hallazgos',
        color: Colors.green.shade700,
        onPressed: () => Navigator.pushNamed(
          context,
          AppRoutes.reporteHallazgos,
          arguments: {'incidenteId': inc.id},
          // F.4: NO llamar evaluar() aquí — POST /reportes/hallazgos
          // ya finaliza el incidente internamente (CrearReporteHallazgosService).
        ),
      ));
    }

    // Cancelar — cualquier estado activo
    if (inc.estaActivo) {
      if (botones.isNotEmpty) botones.add(const SizedBox(height: 10));
      botones.add(_boton(
        label: 'Cancelar emergencia',
        color: Colors.red,
        outlined: true,
        onPressed: () => _ejecutar(
          () => service.cancelar(inc.id),
          mensajeExito: 'Emergencia cancelada.',
        ),
      ));
    }

    return botones;
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
  }) {
    final shape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14));

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
              onPressed: onPressed,
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            )
          : ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: shape,
              ),
              onPressed: onPressed,
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
    );
  }

  Widget _fila(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade500),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.negroTexto)),
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