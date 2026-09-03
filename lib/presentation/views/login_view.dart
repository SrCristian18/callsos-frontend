import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/app_routes.dart';
import '../../core/colores_app.dart';
import '../../data/services/notificacion_service.dart';
import '../viewmodels/sesion_viewmodel.dart';
import '../widgets/app_password_field.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/custom_input.dart';
import '../widgets/primary_loading_button.dart';

/// Login del denunciante.
///
/// F.5 — conecta con [SesionViewModel] (login real) y registra el token
/// FCM tras el éxito para habilitar notificaciones push del backend.
///
/// La vista anterior usaba [LoginViewModel] (mock). Ahora usa el mismo
/// [SesionViewModel] que [LoginPoliciaView] — mismo patrón, distinta ruta
/// de destino (DENUNCIANTE → [HomeDenuncianteView]).
///
/// EPIC-13 (Design System, auditoría UX/UI) — error y botón de carga
/// migrados a [AuthErrorBanner]/[PrimaryLoadingButton] (widgets
/// compartidos nuevos), en vez de los bloques a mano que tenía antes —
/// mismo tratamiento visual que ya usan [LoginPoliciaView],
/// [RegisterDenuncianteView] y [RegisterPoliciaView].
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _userController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLoginPressed(SesionViewModel sesion) async {
    if (_userController.text.isEmpty || _passwordController.text.isEmpty) {
      return;
    }

    final exito = await sesion.login(
      username: _userController.text.trim(),
      password: _passwordController.text,
    );

    if (exito && mounted) {
      // F.5 — Registrar token FCM solo si Firebase está habilitado.
      // Épica 8 (hallazgo #5): antes solo se llamaba para DENUNCIANTE
      // ("el backend solo usa tokenFcm para denunciantes" — desactualizado
      // desde Épica 5). Ahora se llama siempre que haya rol; el propio
      // NotificacionService despacha al servicio correcto según el rol
      // (o lo ignora silenciosamente si es COMANDO).
      if (AppConfig.firebaseHabilitado && sesion.rol != null) {
        context.read<NotificacionService>().registrarTokenEnBackend(
              actorId: sesion.actorId!,
              rol: sesion.rol!,
            );
      }
      Navigator.pushReplacementNamed(context, AppRoutes.homeDenunciante);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blancoVerde,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: AppColors.verdeOscuro),
          tooltip: 'Volver',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: Consumer<SesionViewModel>(
            builder: (context, sesion, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.person_search,
                      size: 80, color: AppColors.verdeOscuro),
                  const SizedBox(height: 20),
                  const Text(
                    'Acceso ciudadano',
                    style: TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Inicia sesión para reportar emergencias'),
                  const SizedBox(height: 30),

                  CustomInput(
                    hintText: 'Usuario',
                    icon: Icons.person_outline,
                    controller: _userController,
                  ),

                  AppPasswordField(
                    hintText: 'Contraseña',
                    icon: Icons.lock_outline,
                    controller: _passwordController,
                  ),

                  if (sesion.errorMessage != null) ...[
                    const SizedBox(height: 8),
                    AuthErrorBanner(mensaje: sesion.errorMessage!),
                  ],

                  const SizedBox(height: 10),

                  PrimaryLoadingButton(
                    label: 'Iniciar sesión',
                    isLoading: sesion.isLoading,
                    onPressed: () => _onLoginPressed(sesion),
                  ),

                  const SizedBox(height: 14),
                  Center(
                    child: InkWell(
                      onTap: () => Navigator.pushNamed(
                          context, AppRoutes.forgotPassword),
                      // EPIC-14: touch target mínimo 48dp — el
                      // `Padding(8)` de antes daba ~33dp de alto (14sp
                      // de texto + 16 de padding), por debajo del
                      // mínimo. `Container` con `constraints.minHeight`
                      // agranda el área tocable sin cambiar el tamaño
                      // visible del texto (sigue centrado adentro).
                      child: Container(
                        alignment: Alignment.center,
                        constraints: const BoxConstraints(minHeight: 48),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: const Text(
                          '¿Olvidaste tu contraseña?',
                          // EPIC-14: verdeClaro (#7EAD1F) da 2.66:1 de
                          // contraste sobre blanco — falla AA (mínimo
                          // 4.5:1 texto normal). verdeTexto es el mismo
                          // verde, oscurecido para pasar AA (4.78:1),
                          // sin tocar el swatch de marca.
                          style: TextStyle(
                              color: AppColors.verdeTexto,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}