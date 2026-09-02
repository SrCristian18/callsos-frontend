import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'package:CallSos/data/services/agente_service.dart';
import 'package:CallSos/data/services/api_client.dart';
import 'package:CallSos/data/services/auditoria_service.dart';
import 'package:CallSos/data/services/auth_service.dart';
import 'package:CallSos/data/services/cai_service.dart';
import 'package:CallSos/data/services/denunciante_service.dart';
import 'package:CallSos/data/services/geolocalizacion_service.dart';
import 'package:CallSos/data/services/incidente_service.dart';
import 'package:CallSos/data/services/notificacion_service.dart';
import 'package:CallSos/data/services/preferencias_storage.dart';
import 'package:CallSos/data/services/reporte_service.dart';
import 'package:CallSos/data/services/stomp_service.dart';
import 'package:CallSos/presentation/viewmodels/crear_incidente_viewmodel.dart';
import 'package:CallSos/presentation/viewmodels/sesion_viewmodel.dart';
import 'package:CallSos/presentation/viewmodels/theme_viewmodel.dart';

/// Épica 3 (integración funcional completa): se retiraron de este archivo
/// los providers de LoginViewModel, ReporteViewModel,
/// RegisterPoliciaViewModel e IncidenteViewModel (legacy) — sus únicos
/// consumidores eran IncidenteView/ReporteView (rutas legacy ya
/// eliminadas, ver app_routes.dart) y 3 widgets huérfanos
/// (comando_widget/jefecai_widget/agente_widget), confirmados
/// inalcanzables desde cualquier flujo real de navegación. Con ellos se
/// fue también `_agentePoliciaDesdeSesion`, que solo alimentaba al
/// IncidenteViewModel legacy.

class AppProviders {
  static List<SingleChildWidget> get providers {
    // Instancias compartidas de la capa de red.
    final apiClient = ApiClient();
    final authService = AuthService(apiClient);

    return [
      // ── F.0.6 — Geolocalización ─────────────────────────────────────
      Provider<IGeolocalizacionService>(
        create: (_) => GeolocalizacionService(),
      ),

      // ── EPIC-02 (Design System) — tema claro/oscuro ──────────────────
      // Va temprano, sin depender de nada más (igual que Geolocalización)
      // — MaterialApp lo necesita para decidir themeMode antes de
      // construir cualquier pantalla.
      ChangeNotifierProvider<ThemeViewModel>(
        create: (_) {
          final vm = ThemeViewModel(storage: SharedPreferencesAdapter());
          // Fire-and-forget: mismo patrón que sesion.restaurarSesion()
          // más abajo — no bloquea el primer build. Mientras se resuelve,
          // themeMode ya vale ThemeMode.system (default del constructor),
          // así que no hay parpadeo hacia un tema "vacío".
          vm.cargarTemaGuardado();
          return vm;
        },
      ),

      // ── F.0.3 — Servicios de red ────────────────────────────────────
      Provider<IIncidenteService>(
        create: (_) => IncidenteService(apiClient),
      ),
      Provider<IReporteService>(
        create: (_) => ReporteService(apiClient),
      ),
      Provider<IDenuncianteService>(
        create: (_) => DenuncianteService(apiClient),
      ),
      Provider<ICaiService>(
        create: (_) => CaiService(apiClient),
      ),
      // Épica 8 (hallazgo #5): antes no existía ningún servicio dedicado
      // al recurso Agente — ver docstring de `agente_service.dart`.
      Provider<IAgenteService>(
        create: (_) => AgenteService(apiClient),
      ),
      // ── EPIC-07 — Auditorías e historiales (Timeline) ────────────────
      Provider<IAuditoriaService>(
        create: (_) => AuditoriaService(apiClient),
      ),

      // ── F.5 — Notificaciones push ───────────────────────────────────
      // Épica 8 (hallazgo #5): antes dependía solo de IDenuncianteService
      // — ahora despacha según el rol del actor (DENUNCIANTE/AGENTE/
      // OPERADOR_CAI), ver `NotificacionService.registrarTokenEnBackend`.
      ProxyProvider3<IDenuncianteService, IAgenteService, ICaiService,
          NotificacionService>(
        create: (context) => NotificacionService(
          denuncianteService: context.read<IDenuncianteService>(),
          agenteService: context.read<IAgenteService>(),
          caiService: context.read<ICaiService>(),
        ),
        update: (_, denuncianteService, agenteService, caiService, previous) =>
            previous ??
            NotificacionService(
              denuncianteService: denuncianteService,
              agenteService: agenteService,
              caiService: caiService,
            ),
      ),

      // ── F.0.4 — Sesión (DEBE ir antes de cualquier ProxyProvider
      //             que dependa de SesionViewModel) ────────────────────
      ChangeNotifierProvider<SesionViewModel>(
        create: (_) {
          final sesion = SesionViewModel(authService: authService);
          // Conecta el JWT con ApiClient para que todas las peticiones
          // incluyan Authorization: Bearer <token>.
          apiClient.tokenProvider = sesion;
          // Dispara restaurarSesion() sin bloquear el build inicial.
          sesion.restaurarSesion();
          return sesion;
        },
      ),

      // ── F.3 — STOMP (depende de SesionViewModel → va después) ───────
      ProxyProvider<SesionViewModel, IStompService>(
        create: (context) => StompService(
          tokenProvider: context.read<SesionViewModel>(),
        ),
        update: (_, sesion, previous) =>
            previous ?? StompService(tokenProvider: sesion),
      ),

      // ── F.1 — Botón de pánico (una sola instancia) ──────────────────
      // ChangeNotifierProxyProvider2 porque depende de IIncidenteService
      // e IGeolocalizacionService (ambos estáticos — nunca cambian, pero
      // el patrón asegura que se inyecten correctamente).
      ChangeNotifierProxyProvider2<IIncidenteService, IGeolocalizacionService,
          CrearIncidenteViewModel>(
        create: (context) => CrearIncidenteViewModel(
          incidenteService: context.read<IIncidenteService>(),
          geoService: context.read<IGeolocalizacionService>(),
        ),
        update: (_, incidenteService, geoService, previous) =>
            previous ??
            CrearIncidenteViewModel(
              incidenteService: incidenteService,
              geoService: geoService,
            ),
      ),
    ];
  }
}