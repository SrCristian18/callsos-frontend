import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'package:CallSos/data/models/agente_policia.dart';
import 'package:CallSos/data/models/enums/estado_agente.dart';
import 'package:CallSos/data/models/enums/rol.dart';
import 'package:CallSos/data/services/api_client.dart';
import 'package:CallSos/data/services/auth_service.dart';
import 'package:CallSos/data/services/denunciante_service.dart';
import 'package:CallSos/data/services/geolocalizacion_service.dart';
import 'package:CallSos/data/services/incidente_service.dart';
import 'package:CallSos/data/services/notificacion_service.dart';
import 'package:CallSos/data/services/reporte_service.dart';
import 'package:CallSos/data/services/stomp_service.dart';
import 'package:CallSos/presentation/viewmodels/crear_incidente_viewmodel.dart';
import 'package:CallSos/presentation/viewmodels/incidente_viewmodel.dart';
import 'package:CallSos/presentation/viewmodels/login_viewmodel.dart';
import 'package:CallSos/presentation/viewmodels/register_policia_viewmodel.dart';
import 'package:CallSos/presentation/viewmodels/reporte_viewmodel.dart';
import 'package:CallSos/presentation/viewmodels/sesion_viewmodel.dart';

/// Construye un [AgentePolicia] desde la sesión activa.
///
/// DEUDA DE BACKEND (F.0.7): `cai` y `estadoAgente` son placeholders
/// porque `AuthResponse` no expone perfil completo del agente.
AgentePolicia _agentePoliciaDesdeSesion(SesionViewModel sesion) {
  if (!sesion.isAuthenticated) {
    return AgentePolicia(
      id: '',
      nombre: '',
      rol: Rol.DENUNCIANTE,
      estadoAgente: EstadoAgente.DISPONIBLE,
    );
  }
  return AgentePolicia(
    id: sesion.actorId!,
    nombre: sesion.nombrePlaceholder,
    rol: sesion.rol!,
    cai: 'CAI San Francisco', // TODO(F.0.7): placeholder
    estadoAgente: EstadoAgente.DISPONIBLE, // TODO(F.0.7): placeholder
  );
}

class AppProviders {
  static List<SingleChildWidget> get providers {
    // Instancias compartidas de la capa de red.
    final apiClient = ApiClient();
    final authService = AuthService(apiClient);

    return [
      // ── ViewModels legacy (mantener hasta retiro post-F.7) ─────────
      ChangeNotifierProvider(create: (_) => LoginViewModel()),
      ChangeNotifierProvider(create: (_) => ReporteViewModel()),
      ChangeNotifierProvider(create: (_) => RegisterPoliciaViewModel()),

      // ── F.0.6 — Geolocalización ─────────────────────────────────────
      Provider<IGeolocalizacionService>(
        create: (_) => GeolocalizacionService(),
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

      // ── F.5 — Notificaciones push ───────────────────────────────────
      ProxyProvider<IDenuncianteService, NotificacionService>(
        create: (context) => NotificacionService(
          denuncianteService: context.read<IDenuncianteService>(),
        ),
        update: (_, denuncianteService, previous) =>
            previous ??
            NotificacionService(denuncianteService: denuncianteService),
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

      // ── F.0.4 — IncidenteViewModel sincronizado con la sesión ────────
      ChangeNotifierProxyProvider<SesionViewModel, IncidenteViewModel>(
        create: (context) => IncidenteViewModel(
          currentUser:
              _agentePoliciaDesdeSesion(context.read<SesionViewModel>()),
        ),
        update: (_, sesion, previous) {
          final usuario = _agentePoliciaDesdeSesion(sesion);
          if (previous == null) {
            return IncidenteViewModel(currentUser: usuario);
          }
          previous.actualizarUsuario(usuario);
          return previous;
        },
      ),
    ];
  }
}