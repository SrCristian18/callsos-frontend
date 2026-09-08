import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_routes.dart';
import '../../core/colores_app.dart';
import '../viewmodels/sesion_viewmodel.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/custom_input.dart';
import '../widgets/primary_loading_button.dart';

/// Recuperación de contraseña — paso 1: solicitar el token por correo.
///
/// FIX (auditoría AUD-1): esta vista antes NO llamaba a ningún endpoint
/// — el comentario original decía "REQUIERE CAMBIO DE BACKEND: no existe
/// (todavía) ningún endpoint de recuperación de contraseña" y el botón
/// solo mostraba una advertencia (`AppSnackBar.advertencia`). Eso dejó
/// de ser cierto: el backend YA expone `POST /auth/recuperar-password` y
/// `POST /auth/resetear-password` completos (`AuthController`, Épica 8
/// hallazgo #6 — services, ports, adapters y la tabla
/// `tokens_reseteo_password` ya existen), pero nadie volvió a conectar
/// esta pantalla. Ahora sí llama al backend real, con el mismo patrón de
/// loading/error que el resto del flujo de auth
/// ([AuthErrorBanner]/[PrimaryLoadingButton], vía [SesionViewModel]).
///
/// Al confirmar, el backend responde SIEMPRE con el mismo mensaje
/// genérico (exista o no una cuenta con ese correo, para no revelar
/// información — ver docstring de `SolicitarReseteoPasswordPort` en el
/// backend). Esta vista respeta eso: nunca infiere ni comunica si el
/// correo existe, solo muestra el mensaje del backend y avanza al paso 2
/// ([ResetPasswordView]), donde el usuario ingresa el token que le llegó
/// por correo junto con su nueva contraseña.
class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final _correoController = TextEditingController();

  @override
  void dispose() {
    _correoController.dispose();
    super.dispose();
  }

  Future<void> _onEnviarPressed(SesionViewModel sesion) async {
    final correo = _correoController.text.trim();
    if (correo.isEmpty) return;

    final mensaje = await sesion.recuperarPassword(correo: correo);

    if (mensaje != null && mounted) {
      // El backend ya respondió con éxito (mensaje genérico, ver
      // docstring de la clase) — se avanza al paso 2 pasando el correo
      // solo para prellenar contexto visual, nunca como dato sensible.
      Navigator.pushNamed(
        context,
        AppRoutes.resetPassword,
        arguments: correo,
      );
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
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Consumer<SesionViewModel>(
            builder: (context, sesion, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 50),
                  const Text(
                    '¿Olvidaste tu contraseña?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.negroTexto,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  CustomInput(
                    hintText: 'Ingrese su dirección de correo',
                    icon: Icons.email_outlined,
                    controller: _correoController,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Te llegará un código para restablecer tu contraseña.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.verdeTexto, fontSize: 14),
                  ),

                  if (sesion.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    AuthErrorBanner(mensaje: sesion.errorMessage!),
                  ],

                  const SizedBox(height: 20),
                  PrimaryLoadingButton(
                    label: 'Enviar',
                    isLoading: sesion.isLoading,
                    onPressed: () => _onEnviarPressed(sesion),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.resetPassword,
                      arguments: _correoController.text.trim().isEmpty
                          ? null
                          : _correoController.text.trim(),
                    ),
                    child: const Text('Ya tengo un código'),
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