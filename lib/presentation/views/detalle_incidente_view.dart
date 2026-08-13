import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_routes.dart';
import '../../core/colores_app.dart';
import '../../data/models/enums/estado_incidente.dart';
import '../../data/models/enums/rol.dart';
import '../../data/models/incidente.dart';
import '../../data/models/tipo_incidente_presentacion.dart';
import '../../data/services/api_exception.dart';
import '../../data/services/incidente_service.dart';
import '../viewmodels/sesion_viewmodel.dart';
import '../widgets/estado_chip.dart';

/// Detalle completo de un incidente.
///
/// F.2 — Home views por rol + Detalle de Incidente.
///
/// Recibe `incidenteId` como argumento de ruta y llama
/// `GET /incidentes/{id}`.
///
/// Botones contextuales según rol + estado:
/// - DENUNCIANTE + AGENTE_EN_CAMINO → "Ver agente en mapa" (→ TrackingView F.3).
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

  late String _incidenteId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(mensajeExito),
              backgroundColor: Colors.green),
        );
      }
      if (rutaPostExito != null && mounted) {
        Navigator.pushNamed(context, rutaPostExito, arguments: args);
      } else {
        await _cargar(); // refrescar el detalle
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.message), backgroundColor: Colors.red),
        );
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

          // ── Botones contextuales ────────────────────────────────────
          if (!_enProceso) ..._botonesContextuales(inc, rol, service)
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
      Incidente inc, Rol? rol, IIncidenteService service) {
    final botones = <Widget>[];

    // DENUNCIANTE + AGENTE_EN_CAMINO → ver en mapa
    if (rol == Rol.DENUNCIANTE &&
        inc.estado == EstadoIncidente.AGENTE_EN_CAMINO) {
      botones.add(_boton(
        label: '📍 Ver agente en mapa',
        color: AppColors.verdeOscuro,
        onPressed: () => Navigator.pushNamed(
          context,
          AppRoutes.tracking,
          arguments: {'incidenteId': inc.id},
        ),
      ));
    }

    // AGENTE + AGENTE_ASIGNADO → en camino
    if (rol == Rol.AGENTE &&
        inc.estado == EstadoIncidente.AGENTE_ASIGNADO) {
      botones.add(_boton(
        label: '🚓 Ir en camino',
        color: Colors.blue.shade700,
        onPressed: () => _ejecutar(
          () => service.enCamino(inc.id),
          mensajeExito: 'Marcaste que vas en camino.',
        ),
      ));
    }

    // AGENTE + AGENTE_EN_CAMINO → atender
    if (rol == Rol.AGENTE &&
        inc.estado == EstadoIncidente.AGENTE_EN_CAMINO) {
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