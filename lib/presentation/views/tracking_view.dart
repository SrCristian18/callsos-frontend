import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/colores_app.dart';
import '../../data/models/enums/rol.dart';
import '../../data/models/incidente.dart';
import '../../data/models/valueobject/ubicacion.dart';
import '../../data/services/geolocalizacion_service.dart';
import '../../data/services/incidente_service.dart';
import 'package:CallSos/data/services/stomp_sevice.dart';
import '../viewmodels/sesion_viewmodel.dart';
import '../viewmodels/tracking_viewmodel.dart';

/// Vista de seguimiento en tiempo real del agente en camino.
///
/// F.3 — TrackingView + TrackingViewModel + WebSocket STOMP.
///
/// Recibe `incidenteId` como argumento de ruta. Internamente:
/// 1. Carga el detalle del incidente (GET /{id}) para obtener coordenadas
///    del punto de emergencia y centrar el mapa.
/// 2. Inicia [TrackingViewModel] en modo receptor (DENUNCIANTE) o emisor
///    (AGENTE) según el rol de la sesión.
/// 3. Muestra [FlutterMap] con tiles OpenStreetMap y los marcadores:
///    - 🔴 Punto de la emergencia (coordenadas del incidente).
///    - 🔵 Agente (actualizado en tiempo real vía STOMP).
///    - 📍 Denunciante (posición inicial del incidente, estática).
class TrackingView extends StatefulWidget {
  const TrackingView({super.key});

  @override
  State<TrackingView> createState() => _TrackingViewState();
}

class _TrackingViewState extends State<TrackingView> {
  late TrackingViewModel _vm;
  final MapController _mapController = MapController();

  Incidente? _incidente;
  bool _cargandoIncidente = true;
  String? _errorCarga;

  @override
  void initState() {
    super.initState();
    _vm = TrackingViewModel(
      stomp: StompService(
        tokenProvider: context.read<SesionViewModel>(),
      ),
      geo: context.read<IGeolocalizacionService>(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final incidenteId = args?['incidenteId'] as String? ?? '';
    if (incidenteId.isNotEmpty) _inicializar(incidenteId);
  }

  Future<void> _inicializar(String incidenteId) async {
    // 1 — cargar detalle del incidente para obtener coords del punto
    try {
      final inc =
          await context.read<IIncidenteService>().consultar(incidenteId);
      if (!mounted) return;
      setState(() {
        _incidente = inc;
        _cargandoIncidente = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorCarga = 'No se pudo cargar el incidente.';
          _cargandoIncidente = false;
        });
        return;
      }
    }

    // 2 — iniciar tracking
    final sesion = context.read<SesionViewModel>();
    await _vm.iniciar(
      incidenteId: incidenteId,
      rol: sesion.rol ?? Rol.DENUNCIANTE,
      actorId: sesion.actorId ?? '',
      posicionInicial: _incidente != null
          ? Ubicacion(
              latitud: _incidente!.latitud,
              longitud: _incidente!.longitud,
            )
          : null,
    );

    // 3 — escuchar actualizaciones de posición para mover el mapa
    _vm.addListener(_onPosicionActualizada);
  }

  void _onPosicionActualizada() {
    if (_vm.posicionAgente != null) {
      _mapController.move(_vm.posicionAgente!, 15);
    }
  }

  @override
  void dispose() {
    _vm.removeListener(_onPosicionActualizada);
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _vm,
      child: Scaffold(
        backgroundColor: AppColors.blancoVerde,
        appBar: AppBar(
          backgroundColor: AppColors.verdeOscuro,
          leading: IconButton(
            icon:
                const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Seguimiento en tiempo real',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            Consumer<TrackingViewModel>(
              builder: (_, vm, __) => Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _ConexionIndicador(estado: vm.conexion),
              ),
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_cargandoIncidente) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.verdeOscuro),
      );
    }

    if (_errorCarga != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_outlined,
                  size: 52, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(_errorCarga!,
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: Colors.grey.shade600, fontSize: 14)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.verdeOscuro,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    _cargandoIncidente = true;
                    _errorCarga = null;
                  });
                  if (_incidente != null) {
                    _inicializar(_incidente!.id);
                  }
                },
              ),
            ],
          ),
        ),
      );
    }

    // Posición inicial del mapa: agente si ya la tenemos, si no la del
    // incidente, si no Cartagena (fallback).
    final centroInicial = _vm.posicionAgente ??
        (_incidente != null
            ? LatLng(_incidente!.latitud, _incidente!.longitud)
            : const LatLng(10.391, -75.4794));

    return Consumer<TrackingViewModel>(
      builder: (_, vm, __) => Stack(
        children: [
          // ── Mapa ───────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: centroInicial,
              initialZoom: 15,
              minZoom: 10,
              maxZoom: 18,
            ),
            children: [
              // Tiles OpenStreetMap (sin API key)
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.callsos.frontend',
              ),

              MarkerLayer(
                markers: [
                  // Marcador del punto de emergencia (estático)
                  if (_incidente != null)
                    Marker(
                      point: LatLng(
                          _incidente!.latitud, _incidente!.longitud),
                      width: 40,
                      height: 40,
                      child: const _MarcadorEmergencia(),
                    ),

                  // Marcador del agente (actualizado en tiempo real)
                  if (vm.posicionAgente != null)
                    Marker(
                      point: vm.posicionAgente!,
                      width: 44,
                      height: 44,
                      child: const _MarcadorAgente(),
                    ),

                  // Marcador del denunciante (estático — posición inicial)
                  if (vm.posicionDenunciante != null)
                    Marker(
                      point: vm.posicionDenunciante!,
                      width: 36,
                      height: 36,
                      child: const _MarcadorDenunciante(),
                    ),
                ],
              ),
            ],
          ),

          // ── Panel inferior de info ──────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _PanelInfo(vm: vm, incidente: _incidente),
          ),

          // ── Error de conexión inline ────────────────────────────────
          if (vm.conexion == TrackingConexionEstado.error)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.red.shade600,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                child: Row(children: [
                  const Icon(Icons.wifi_off, color: Colors.white,
                      size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      vm.errorMessage ??
                          'Error de conexión con el servidor de tracking.',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12),
                    ),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Marcadores ────────────────────────────────────────────────────────────────

class _MarcadorEmergencia extends StatelessWidget {
  const _MarcadorEmergencia();

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
                color: Colors.red.withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: 2)
          ],
        ),
        child:
            const Icon(Icons.emergency_share, color: Colors.white, size: 22),
      );
}

class _MarcadorAgente extends StatelessWidget {
  const _MarcadorAgente();

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.blue.shade700,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            BoxShadow(
                color: Colors.blue.withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: 2)
          ],
        ),
        child:
            const Icon(Icons.local_police, color: Colors.white, size: 24),
      );
}

class _MarcadorDenunciante extends StatelessWidget {
  const _MarcadorDenunciante();

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.orange.shade600,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: const Icon(Icons.person_pin, color: Colors.white, size: 20),
      );
}

// ── Panel inferior ────────────────────────────────────────────────────────────

class _PanelInfo extends StatelessWidget {
  final TrackingViewModel vm;
  final Incidente? incidente;
  const _PanelInfo({required this.vm, required this.incidente});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, -2))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(
              vm.estaConectado ? Icons.sensors : Icons.sensors_off,
              color:
                  vm.estaConectado ? Colors.green : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              vm.estaConectado
                  ? 'Tracking en tiempo real activo'
                  : vm.conexion == TrackingConexionEstado.conectando
                      ? 'Conectando...'
                      : 'Sin conexión de tracking',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: vm.estaConectado
                    ? AppColors.negroTexto
                    : Colors.grey,
              ),
            ),
          ]),
          if (vm.posicionAgente != null) ...[
            const SizedBox(height: 8),
            Text(
              'Agente: ${vm.posicionAgente!.latitude.toStringAsFixed(4)}, '
              '${vm.posicionAgente!.longitude.toStringAsFixed(4)}',
              style:
                  TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
          if (vm.conexion == TrackingConexionEstado.conectando) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],

          // Leyenda
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _leyendaItem(
                  color: Colors.red, icon: Icons.emergency_share,
                  label: 'Emergencia'),
              _leyendaItem(
                  color: Colors.blue.shade700, icon: Icons.local_police,
                  label: 'Agente'),
              _leyendaItem(
                  color: Colors.orange.shade600, icon: Icons.person_pin,
                  label: 'Denunciante'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _leyendaItem(
      {required Color color,
      required IconData icon,
      required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 14),
        ),
        const SizedBox(width: 4),
        Text(label,
            style:
                const TextStyle(fontSize: 11, color: AppColors.negroTexto)),
      ],
    );
  }
}

// ── Indicador de conexión en AppBar ──────────────────────────────────────────

class _ConexionIndicador extends StatelessWidget {
  final TrackingConexionEstado estado;
  const _ConexionIndicador({required this.estado});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;

    switch (estado) {
      case TrackingConexionEstado.conectado:
        color = Colors.greenAccent;
        icon = Icons.wifi;
      case TrackingConexionEstado.conectando:
        color = Colors.orange;
        icon = Icons.wifi_find;
      case TrackingConexionEstado.error:
        color = Colors.red.shade300;
        icon = Icons.wifi_off;
      case TrackingConexionEstado.desconectado:
        color = Colors.white38;
        icon = Icons.wifi_off;
    }

    return Icon(icon, color: color, size: 20);
  }
}