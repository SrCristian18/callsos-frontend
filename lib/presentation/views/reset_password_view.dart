import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_routes.dart';
import '../../core/colores_app.dart';
import '../viewmodels/sesion_viewmodel.dart';
import '../widgets/app_password_field.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/custom_input.dart';
import '../widgets/primary_loading_button.dart';

/// Recuperación de contraseña — paso 2: completar el reseteo con el
/// token recibido por correo + la nueva contraseña.
///
/// FIX (auditoría AUD-1): esta pantalla no existía. El backend ya
/// exponía `POST /auth/resetear-password` completo (`AuthController`,
/// Épica 8 hallazgo #6), pero no había ninguna forma de llegar a usarlo
/// desde la app — [ForgotPasswordView] (paso 1) terminaba en un
/// callejón sin salida incluso después de conectarla al backend, porque
/// el usuario no tenía dónde ingresar el token que le llegaba por
/// correo. Espejo de `ResetearPasswordRequest`
/// (`token`, `nuevaPassword`, `confirmarPassword`).
///
/// [correoPrellenado] es puramente informativo (mostrado como recordatorio
/// de a qué correo se envió el token) — nunca se envía al backend en
/// este paso, que solo necesita el token.
class ResetPasswordView extends StatefulWidget {
  final String? correoPrellenado;

  const ResetPasswordView({super.key, this.correoPrellenado});

  @override
  State<ResetPasswordView> createState() => _ResetPasswordViewState();
}

class _ResetPasswordViewState extends State<ResetPasswordView> {
  final _tokenController = TextEditingController();
  final _nuevaPasswordController = TextEditingController();
  final _confirmarPasswordController = TextEditingController();

  @override
  void dispose() {
    _tokenController.dispose();
    _nuevaPasswordController.dispose();
    _confirmarPasswordController.dispose();
    super.dispose();
  }

  bool get _camposCompletos =>
      _tokenController.text.isNotEmpty &&
      _nuevaPasswordController.text.isNotEmpty &&
      _confirmarPasswordController.text.isNotEmpty;

  Future<void> _onConfirmarPressed(SesionViewModel sesion) async {
    if (!_camposCompletos) return;

    final exito = await sesion.resetearPassword(
      token: _tokenController.text.trim(),
      nuevaPassword: _nuevaPasswordController.text,
      confirmarPassword: _confirmarPasswordController.text,
    );

    if (exito && mounted) {
      AppSnackBar.exito(
        context,
        'Tu contraseña fue actualizada correctamente. Inicia sesión con '
        'tu nueva contraseña.',
      );
      // Vuelve al inicio del flujo de auth (selección de rol / login),
      // limpiando todo el stack de recuperación — no tiene sentido poder
      // "volver" a estas dos pantallas tras un reseteo exitoso.
      Navigator.popUntil(context, (route) => route.isFirst);
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
                  const Icon(Icons.lock_reset,
                      size: 70, color: AppColors.verdeOscuro),
                  const SizedBox(height: 16),
                  const Text(
                    'Restablecer contraseña',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      widget.correoPrellenado != null
                          ? 'Ingresa el código que enviamos a '
                              '${widget.correoPrellenado} junto con tu '
                              'nueva contraseña.'
                          : 'Ingresa el código que recibiste por correo '
                              'junto con tu nueva contraseña.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 24),

                  CustomInput(
                    hintText: 'Código de verificación',
                    icon: Icons.vpn_key_outlined,
                    controller: _tokenController,
                  ),
                  AppPasswordField(
                    hintText: 'Nueva contraseña',
                    icon: Icons.lock_outline,
                    controller: _nuevaPasswordController,
                  ),
                  AppPasswordField(
                    hintText: 'Confirmar nueva contraseña',
                    icon: Icons.lock_outline,
                    controller: _confirmarPasswordController,
                  ),

                  if (sesion.errorMessage != null) ...[
                    const SizedBox(height: 8),
                    AuthErrorBanner(mensaje: sesion.errorMessage!),
                  ],

                  const SizedBox(height: 16),

                  PrimaryLoadingButton(
                    label: 'Restablecer contraseña',
                    isLoading: sesion.isLoading,
                    onPressed: () => _onConfirmarPressed(sesion),
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