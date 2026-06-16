import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_routes.dart';
import '../../core/colores_app.dart';
import '../../data/models/enums/rol.dart';
import '../viewmodels/sesion_viewmodel.dart';

/// Pantalla de inicio — decide la ruta inicial según la sesión.
///
/// F.0.5 — Mapa de navegación y esqueletos.
///
/// Flujo:
/// 1. [AppProviders] ya disparó [SesionViewModel.restaurarSesion] al
///    construirse; [SesionViewModel.isLoading] arranca en `true`.
/// 2. Esta vista escucha [SesionViewModel] y muestra logo + spinner
///    mientras `isLoading == true`.
/// 3. Cuando `isLoading` pasa a `false`:
///    - `isAuthenticated == true`  → home del rol ([_rutaPorRol]).
///    - `isAuthenticated == false` → [AppRoutes.roleSelection].
///
/// Usa [Navigator.pushReplacementNamed] para que el usuario no pueda
/// volver al splash con el botón "atrás".
class SplashView extends StatelessWidget {
  const SplashView({super.key});

  /// Home correspondiente al rol autenticado.
  String _rutaPorRol(Rol rol) {
    switch (rol) {
      case Rol.DENUNCIANTE:
        return AppRoutes.homeDenunciante;
      case Rol.AGENTE:
        return AppRoutes.homeAgente;
      case Rol.OPERADOR_CAI:
        return AppRoutes.homeCai;
      case Rol.COMANDO:
        return AppRoutes.homeComando;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SesionViewModel>(
      builder: (context, sesion, _) {
        // Navegar en el siguiente frame (después del build) para evitar
        // llamar a Navigator durante la fase de construcción del widget.
        if (!sesion.isLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            final destino = sesion.isAuthenticated
                ? _rutaPorRol(sesion.rol!)
                : AppRoutes.roleSelection;
            Navigator.of(context).pushReplacementNamed(destino);
          });
        }

        return Scaffold(
          backgroundColor: AppColors.blancoVerde,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.emergency_share_rounded,
                  size: 80,
                  color: AppColors.verdeOscuro,
                ),
                const SizedBox(height: 24),
                const Text(
                  'CallSOS',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.negroTexto,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Seguridad ciudadana',
                  style: TextStyle(fontSize: 14, color: AppColors.verdeClaro),
                ),
                const SizedBox(height: 48),
                if (sesion.isLoading)
                  const CircularProgressIndicator(color: AppColors.verdeOscuro),
              ],
            ),
          ),
        );
      },
    );
  }
}