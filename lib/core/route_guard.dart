import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:CallSos/core/app_routes.dart';
import 'package:CallSos/data/models/enums/rol.dart';
import 'package:CallSos/presentation/viewmodels/sesion_viewmodel.dart';

/// Épica 5 — Testing frontend / Navegación.
///
/// Antes de esto, `AppRoutes.routes` era un mapa plano: cualquiera que
/// conociera el nombre de una ruta de Home podía `Navigator.pushNamed`
/// ahí sin importar el rol de la sesión (o sin sesión en absoluto) —
/// solo [SplashView] elegía un destino inicial sensato, pero nada
/// impedía llegar a otra Home después por otro camino.
///
/// [RouteGuard] envuelve la vista protegida y, en cada rebuild
/// (reacciona a cambios de [SesionViewModel] vía [Consumer]):
/// - Si no hay sesión autenticada → redirige a [AppRoutes.roleSelection].
/// - Si hay sesión pero su rol no está en [rolesPermitidos] → redirige a
///   la Home real de ESE rol (vía [AppRoutes.rutaHomeDeRol]) — no a un
///   error genérico, es la misma experiencia que ya da [SplashView].
///
/// La redirección se dispara en `addPostFrameCallback` (nunca durante
/// build) y usa `pushReplacementNamed` para no dejar la ruta protegida
/// en el stack de "atrás".
class RouteGuard extends StatelessWidget {
  const RouteGuard({
    required this.rolesPermitidos,
    required this.child,
    super.key,
  });

  final Set<Rol> rolesPermitidos;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Consumer<SesionViewModel>(
      builder: (context, sesion, _) {
        final String? destino = !sesion.isAuthenticated || sesion.rol == null
            ? AppRoutes.roleSelection
            : (rolesPermitidos.contains(sesion.rol)
                ? null
                : AppRoutes.rutaHomeDeRol(sesion.rol!));

        if (destino != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            Navigator.of(context).pushReplacementNamed(destino);
          });
          // La redirección real ocurre en el frame siguiente — mientras
          // tanto no se muestra la vista protegida ni un Scaffold vacío
          // parpadeante.
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return child;
      },
    );
  }
}