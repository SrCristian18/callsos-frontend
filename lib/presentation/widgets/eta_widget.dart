import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/colores_app.dart';
import '../../data/services/incidente_service.dart';
import '../../data/services/stomp_service.dart';
import '../viewmodels/eta_viewmodel.dart';

/// Tarjeta que muestra el tiempo estimado de llegada del agente.
///
/// Épica 7: reemplaza el botón "📍 Ver agente en mapa" para el
/// DENUNCIANTE — ese mapa fue retirado por seguridad (fix P6, Épica 3):
/// el denunciante ya no puede ver la posición GPS cruda del agente, ni
/// siquiera indirectamente (esta tarjeta jamás recibe lat/lon — ver
/// `EtaInfo`, que por diseño no tiene esos campos).
///
/// Autocontenido: gestiona su propio [EtaViewModel], pero la conexión
/// STOMP en sí es la MISMA instancia compartida que usa el resto de la
/// app (ver `AppProviders` — `ProxyProvider<SesionViewModel, IStompService>`).
///
/// FIX: antes este widget instanciaba `StompService(tokenProvider: ...)`
/// directamente en `initState()`, ignorando el `IStompService` que
/// `AppProviders` YA registra globalmente para exactamente este
/// propósito. Dos problemas con eso, uno de producción y uno de tests:
///   1. Cada vez que se montaba este widget se abría una conexión
///      WebSocket NUEVA e independiente, en vez de reutilizar la del
///      resto de la app.
///   2. Ningún test podía sustituirla por un fake — cualquier test que
///      montara este widget disparaba un intento de conexión WebSocket
///      REAL, con su Timer de reconexión interno (`stomp_dart_client`)
///      que seguía pendiente incluso después de que Flutter Test
///      destruyera el árbol de widgets ("A Timer is still pending even
///      after the widget tree was disposed").
///
/// `context.read<IStompService>()` sí puede sustituirse en tests por un
/// fake/mock vía `Provider<IStompService>.value(...)` — mismo patrón
/// que ya usan `IIncidenteService`, `SesionViewModel`, etc. en toda la
/// app.
///
/// Se muestra solo cuando el incidente está en `AGENTE_EN_CAMINO` (ver
/// `_botonesContextuales` en `DetalleIncidenteView`) — antes de eso no
/// hay agente en camino cuyo ETA calcular.
class EtaWidget extends StatefulWidget {
  final String incidenteId;

  const EtaWidget({required this.incidenteId, super.key});

  @override
  State<EtaWidget> createState() => _EtaWidgetState();
}

class _EtaWidgetState extends State<EtaWidget> {
  late EtaViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = EtaViewModel(
      stomp: context.read<IStompService>(),
      incidenteService: context.read<IIncidenteService>(),
    );
    _vm.iniciar(widget.incidenteId);
  }

  @override
  void dispose() {
    // FIX: llamar aquí a `_vm.detener()` (async, sin await — dispose()
    // de State no puede ser async) seguido inmediatamente de
    // `_vm.dispose()` provocaba una carrera: cuando el `await
    // _stomp.desconectar()` dentro de detener() finalmente resolvía,
    // intentaba `_setConexion(...)` → `notifyListeners()` sobre un
    // EtaViewModel YA destruido — "A EtaViewModel was used after being
    // disposed". `EtaViewModel.dispose()` ya hace toda la limpieza
    // necesaria (desconecta el WS) sin disparar notifyListeners, así
    // que basta con llamarlo solo a él — mismo patrón que
    // `_TrackingViewState.dispose()` (que nunca llamó a un "detener()"
    // aparte, solo a `_vm.dispose()`).
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _vm,
      child: Consumer<EtaViewModel>(
        builder: (context, vm, _) {
          final eta = vm.eta;
          final tieneDatos = eta?.tieneDatos ?? false;

          final String subtitulo;
          if (tieneDatos) {
            subtitulo =
                '~${eta!.minutosEstimados} min · ${eta.categoriaDistancia!.etiqueta}';
          } else if (vm.conexion == EtaConexionEstado.error) {
            subtitulo = vm.errorMessage ??
                'No se pudo obtener el tiempo estimado.';
          } else {
            subtitulo = 'Calculando tiempo estimado de llegada...';
          }

          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.verdeOscuro.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.verdeOscuro.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.verdeOscuro,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.timer_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tiempo estimado de llegada',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.negroTexto,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitulo,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}