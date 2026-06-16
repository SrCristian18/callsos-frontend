import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'package:CallSos/data/models/agente_policia.dart';
import 'package:CallSos/data/models/enums/estado_agente.dart';
import 'package:CallSos/data/models/enums/rol.dart';
import 'package:CallSos/data/services/api_client.dart';
import 'package:CallSos/data/services/auth_service.dart';
import 'package:CallSos/presentation/viewmodels/incidente_viewmodel.dart';
import 'package:CallSos/presentation/viewmodels/login_viewmodel.dart';
import 'package:CallSos/presentation/viewmodels/register_policia_viewmodel.dart';
import 'package:CallSos/presentation/viewmodels/reporte_viewmodel.dart';
import 'package:CallSos/presentation/viewmodels/sesion_viewmodel.dart';

/// Construye un [AgentePolicia] (modelo usado por [IncidenteViewModel] y
/// las vistas/widgets de rol policial) a partir del estado de
/// [SesionViewModel].
///
/// F.0.4 — Gestión de sesión.
///
/// - Si no hay sesión activa (antes de [SesionViewModel.restaurarSesion]
///   terminar, o tras [SesionViewModel.logout]), devuelve un usuario
///   "vacío" con rol [Rol.DENUNCIANTE] como placeholder — `IncidenteView`
///   (exclusiva de roles policiales) no debería ser alcanzable en este
///   estado; el control de acceso por ruta según sesión es F.0.5.
/// - Si hay sesión activa, usa `actorId`/`rol` REALES del JWT
///   ([SesionViewModel.actorId] / [SesionViewModel.rol]) y
///   [SesionViewModel.nombrePlaceholder] para el nombre.
///
/// DEUDA DE BACKEND (F.0.7): `cai` y `estadoAgente` son placeholders fijos
/// porque `AuthResponse` no expone el perfil completo del agente (CAI
/// asignado, disponibilidad). No afectan autenticación/autorización (eso
/// depende del JWT real vía [ApiClient]), solo datos de presentación que
/// se corregirán cuando exista un endpoint de perfil.
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
    cai: 'CAI San Francisco', // TODO(F.0.7): placeholder, ver doc de la función.
    estadoAgente: EstadoAgente.DISPONIBLE, // TODO(F.0.7): placeholder.
  );
}

class AppProviders {
  static List<SingleChildWidget> get providers {
    // F.0.4 — instancias compartidas de la capa de red.
    //
    // `apiClient.tokenProvider` se conecta MÁS ABAJO, dentro del `create`
    // de SesionViewModel, una vez que `sesion` existe (SesionViewModel
    // implementa ITokenProvider — ver F.0.3/F.0.4).
    final apiClient = ApiClient();
    final authService = AuthService(apiClient);

    return [
      // login_view.dart (denunciante) sigue usando este ViewModel mock por
      // ahora -- el registro/login del denunciante depende de endpoints de
      // backend que aún no existen (ver F.0.7). login_policia_view.dart ya
      // NO usa este provider (ver F.0.4: ahora usa SesionViewModel).
      ChangeNotifierProvider(create: (_) => LoginViewModel()),
      ChangeNotifierProvider(create: (_) => ReporteViewModel()),
      ChangeNotifierProvider(create: (_) => RegisterPoliciaViewModel()),

      // F.0.4 — Sesión real: login/logout/restauración + JWT.
      ChangeNotifierProvider<SesionViewModel>(
        create: (_) {
          final sesion = SesionViewModel(authService: authService);
          // Conecta el JWT actual con ApiClient para que TODAS las
          // peticiones futuras (F.2+) incluyan Authorization: Bearer <token>.
          apiClient.tokenProvider = sesion;
          // Dispara la restauración de sesión sin bloquear el build inicial.
          // `sesion.isLoading` arranca en `true` y SesionViewModel notifica
          // cuando termina (ver doc de `isLoading` en SesionViewModel).
          sesion.restaurarSesion();
          return sesion;
        },
      ),

      // F.0.4: IncidenteViewModel ya NO recibe un AgentePolicia fijo.
      // ChangeNotifierProxyProvider lo mantiene sincronizado con la sesión:
      // cada vez que SesionViewModel notifica (login/logout/restauración),
      // se llama actualizarUsuario() sobre la MISMA instancia (preserva el
      // estado mock _allIncidents hasta la reescritura completa en F.2).
      ChangeNotifierProxyProvider<SesionViewModel, IncidenteViewModel>(
        create: (context) => IncidenteViewModel(
          currentUser: _agentePoliciaDesdeSesion(context.read<SesionViewModel>()),
        ),
        update: (context, sesion, previous) {
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