import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_radius.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
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
///
/// EPIC-09 (Design System, auditoría UX/UI) — "estados de ETA más
/// claros": antes de esta épica los 3 estados posibles (calculando /
/// con datos / error) se diferenciaban SOLO por el texto del
/// subtítulo — el ícono y el color de acento eran siempre los mismos
/// (verde + reloj), así que un error se veía visualmente idéntico a un
/// éxito, y había que leer el texto para notar la diferencia. Ahora
/// cada estado tiene su propio ícono y su propio color de acento
/// ([_EtaEstadoVisual]) — sin tocar [EtaViewModel] ni
/// [EtaConexionEstado]: es pura lectura del estado que el ViewModel ya
/// exponía, no un estado nuevo. (Se evaluó también animar el ícono de
/// "calculando" con un spinner real; ver el comentario de
/// [_EtaEstadoVisual] sobre por qué se descartó.)
class EtaWidget extends StatefulWidget {
  final String incidenteId;

  const EtaWidget({required this.incidenteId, super.key});

  @override
  State<EtaWidget> createState() => _EtaWidgetState();
}

/// Presentación visual (ícono + color) para cada estado de
/// [EtaViewModel] — separado del widget para poder testearlo con un
/// simple `switch` de entrada/salida, sin montar un `Consumer` completo.
///
/// IMPORTANTE: el ícono de "calculando" es estático (`Icons.sync`), NO
/// un `CircularProgressIndicator`. Se probó primero con un spinner de
/// verdad, pero `EtaConexionEstado.conectando` puede quedarse así
/// indefinidamente (mientras el WS sigue intentando conectar — es un
/// estado legítimamente indefinido, no efímero) y un
/// `CircularProgressIndicator` corriendo sin parar hace que
/// `tester.pumpAndSettle()` nunca termine en CUALQUIER test que monte
/// este widget sin resolver la conexión explícitamente — incluido
/// `detalle_incidente_view_test.dart`, que a propósito no lo hace (ver
/// su comentario: "el test de ETA no depende de llegar a estado
/// 'conectado'"). Un ícono estático distinto sigue cumpliendo el
/// objetivo (diferenciar el estado a simple vista) sin ese riesgo.
class _EtaEstadoVisual {
  final IconData icono;
  final Color color;

  const _EtaEstadoVisual(this.icono, this.color);

  factory _EtaEstadoVisual.desde({
    required bool tieneDatos,
    required EtaConexionEstado conexion,
  }) {
    if (tieneDatos) {
      return const _EtaEstadoVisual(Icons.timer_outlined, AppColors.verdeOscuro);
    }
    if (conexion == EtaConexionEstado.error) {
      return const _EtaEstadoVisual(Icons.error_outline, AppColors.error);
    }
    return const _EtaEstadoVisual(Icons.sync, AppColors.verdeOscuro);
  }
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

          final visual = _EtaEstadoVisual.desde(
            tieneDatos: tieneDatos,
            conexion: vm.conexion,
          );

          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: visual.color.withValues(alpha: 0.08),
              borderRadius: AppRadius.borderMd,
              border: Border.all(color: visual.color.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  key: const ValueKey('eta_icono_box'),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: visual.color,
                    borderRadius: AppRadius.borderSm,
                  ),
                  child: Icon(visual.icono, color: Colors.white, size: 22),
                ),
                AppSpacing.gapMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tiempo estimado de llegada',
                        style: AppTextStyles.cuerpo
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                      AppSpacing.gapXs,
                      Text(
                        subtitulo,
                        style: AppTextStyles.cuerpoPequeno
                            .copyWith(color: Colors.grey.shade700),
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