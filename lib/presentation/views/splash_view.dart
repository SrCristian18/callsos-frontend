import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/app_routes.dart';
import '../../core/colores_app.dart';
import '../../data/services/notificacion_service.dart';
import '../viewmodels/sesion_viewmodel.dart';

/// Pantalla de inicio — decide la ruta inicial según la sesión.
///
/// F.0.5 — Mapa de navegación y esqueletos.
/// EPIC-05 (auditoría UX/UI, hallazgo #7) — agrega una animación de
/// apertura breve y elegante (ícono + marca), sin tocar el flujo de
/// decisión de ruta existente.
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
///
/// La animación (~900ms: bien por debajo del límite de 1.5s pedido) es
/// puramente decorativa sobre ESTA misma pantalla — la condición que
/// dispara la navegación (`if (!sesion.isLoading)`, más abajo) es
/// exactamente la misma que ya existía, evaluada en cada `build()`. Si
/// la sesión resuelve antes de que la animación termine, la navegación
/// ocurre igual de inmediato (el criterio de terminado lo pide
/// explícitamente) — la animación no la retrasa ni un frame.
class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _iconOpacity;
  late final Animation<double> _iconScale;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();

    // Duración total de la animación — no de la espera de red que
    // pueda venir después (restaurarSesion ya corre en paralelo desde
    // AppProviders, no depende de este controller).
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Revelado en dos tiempos (ícono primero, marca después) dentro del
    // mismo controller — sutil, sin librerías nuevas.
    _iconOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _iconScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );
    _textOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 1.0, curve: Curves.easeOut),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SesionViewModel>(
      builder: (context, sesion, _) {
        // Navegar en el siguiente frame (después del build) para evitar
        // llamar a Navigator durante la fase de construcción del widget.
        //
        // Sin cambios respecto a la versión anterior a EPIC-05: esta
        // condición no espera ni consulta a la animación en absoluto.
        if (!sesion.isLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;

            // F.5 — Si hay sesión autenticada, registrar/actualizar el
            // token FCM. Solo si Firebase está habilitado (ver AppConfig).
            //
            // Épica 8 (hallazgo #5): antes esto solo se disparaba para
            // DENUNCIANTE — si un AGENTE u OPERADOR_CAI cerraba y volvía
            // a abrir la app (sesión restaurada acá, sin pasar de nuevo
            // por login), su tokenFcm quedaba desactualizado o nunca
            // registrado. `NotificacionService` ya despacha al servicio
            // correcto según el rol (y omite COMANDO), así que basta con
            // quitar la restricción a DENUNCIANTE.
            if (AppConfig.firebaseHabilitado &&
                sesion.isAuthenticated &&
                sesion.rol != null) {
              context.read<NotificacionService>().registrarTokenEnBackend(
                    actorId: sesion.actorId!,
                    rol: sesion.rol!,
                  );
            }

            // Home correspondiente al rol autenticado — mapeo
            // compartido con RouteGuard (ver AppRoutes.rutaHomeDeRol).
            final destino = sesion.isAuthenticated
                ? AppRoutes.rutaHomeDeRol(sesion.rol!)
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
                FadeTransition(
                  opacity: _iconOpacity,
                  child: ScaleTransition(
                    scale: _iconScale,
                    child: const Icon(
                      Icons.emergency_share_rounded,
                      size: 80,
                      color: AppColors.verdeOscuro,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FadeTransition(
                  opacity: _textOpacity,
                  child: SlideTransition(
                    position: _textSlide,
                    child: const Text(
                      'CallSOS',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.negroTexto,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FadeTransition(
                  opacity: _textOpacity,
                  child: SlideTransition(
                    position: _textSlide,
                    child: const Text(
                      'Seguridad ciudadana',
                      style:
                          TextStyle(fontSize: 14, color: AppColors.verdeClaro),
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                // El spinner NO se anima — es un indicador de estado del
                // sistema (heurística #1), debe aparecer de inmediato
                // cuando corresponde, sin competir con la animación de
                // marca ni retrasarse detrás de ella.
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