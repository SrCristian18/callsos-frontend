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

/// Registro de agente mediante token de invitación generado por Comando.
///
/// FIX (Épica 2, punto 3 — deuda_backend.md): el mockup anterior
/// (RegisterPoliciaViewModel, legacy) pedía "Estación/Nombre del
/// CAI/Dirección" como si el agente eligiera su propio CAI, y no tenía
/// ningún campo de usuario. Ambas cosas contradicen el diseño acordado:
/// el CAI sale del token (Comando lo fija al generarlo), nunca lo escribe
/// el agente — por eso esta vista NO tiene ningún campo de CAI.
///
/// Habla directo con [SesionViewModel.registrarAgente] (mismo patrón que
/// [RegisterDenuncianteView]) en vez de RegisterPoliciaViewModel, que
/// queda sin uso — candidato a retiro en la Épica 3 (limpieza de legacy).
///
/// EPIC-13 (Design System, auditoría UX/UI) — error y botón de carga
/// migrados a [AuthErrorBanner]/[PrimaryLoadingButton], unificando el
/// tratamiento visual con [LoginView] y las demás pantallas de auth.
///
/// Épica 8 (hallazgo #5): tras un registro exitoso, registra el token
/// FCM del dispositivo — antes esta vista NUNCA lo hacía, a pesar de que
/// el backend soporta `tokenFcm` para AGENTE desde Épica 5. Mismo
/// patrón que [RegisterDenuncianteView], vía
/// [NotificacionService.registrarTokenEnBackend].
class RegisterPoliciaView extends StatefulWidget {
  const RegisterPoliciaView({super.key});

  @override
  State<RegisterPoliciaView> createState() => _RegisterPoliciaViewState();
}

class _RegisterPoliciaViewState extends State<RegisterPoliciaView> {
  final _tokenController = TextEditingController();
  final _nombreController = TextEditingController();
  final _celularController = TextEditingController();
  final _usuarioController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmarPasswordController = TextEditingController();

  @override
  void dispose() {
    _tokenController.dispose();
    _nombreController.dispose();
    _celularController.dispose();
    _usuarioController.dispose();
    _passwordController.dispose();
    _confirmarPasswordController.dispose();
    super.dispose();
  }

  bool get _camposCompletos =>
      _tokenController.text.isNotEmpty &&
      _nombreController.text.isNotEmpty &&
      _celularController.text.isNotEmpty &&
      _usuarioController.text.isNotEmpty &&
      _passwordController.text.isNotEmpty &&
      _confirmarPasswordController.text.isNotEmpty;

  Future<void> _onRegistrarPressed(SesionViewModel sesion) async {
    if (!_camposCompletos) return;

    final exito = await sesion.registrarAgente(
      token: _tokenController.text.trim(),
      nombre: _nombreController.text.trim(),
      telefono: _celularController.text.trim(),
      username: _usuarioController.text.trim(),
      password: _passwordController.text,
      confirmarPassword: _confirmarPasswordController.text,
    );

    if (exito && mounted) {
      // Épica 8 (hallazgo #5): registrar el token FCM tras el registro,
      // igual que ya hace RegisterDenuncianteView. Esta vista solo
      // registra AGENTE (ver [SesionViewModel.registrarAgente]), pero se
      // usa el mismo despacho por rol que el resto de la app por
      // consistencia — si `sesion.rol` no quedó seteado por algún motivo,
      // simplemente no se llama.
      if (AppConfig.firebaseHabilitado && sesion.rol != null) {
        context.read<NotificacionService>().registrarTokenEnBackend(
              actorId: sesion.actorId!,
              rol: sesion.rol!,
            );
      }
      Navigator.pushReplacementNamed(context, AppRoutes.homeAgente);
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
                  const Icon(Icons.shield_outlined,
                      size: 70, color: AppColors.verdeOscuro),
                  const SizedBox(height: 16),
                  const Text(
                    'Registro de agente',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'Necesitas un token de invitación entregado por tu '
                      'Comando. El CAI al que quedarás asignado ya viene '
                      'incluido en el token.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 24),

                  CustomInput(
                    hintText: 'Token de invitación',
                    icon: Icons.vpn_key_outlined,
                    controller: _tokenController,
                  ),
                  CustomInput(
                    hintText: 'Nombre completo',
                    icon: Icons.badge_outlined,
                    controller: _nombreController,
                  ),
                  CustomInput(
                    hintText: 'Celular',
                    icon: Icons.phone_outlined,
                    controller: _celularController,
                  ),
                  CustomInput(
                    hintText: 'Nombre de usuario',
                    icon: Icons.person_outline,
                    controller: _usuarioController,
                  ),
                  AppPasswordField(
                    hintText: 'Contraseña',
                    icon: Icons.lock_outline,
                    controller: _passwordController,
                  ),
                  AppPasswordField(
                    hintText: 'Confirmar contraseña',
                    icon: Icons.lock_outline,
                    controller: _confirmarPasswordController,
                  ),

                  if (sesion.errorMessage != null) ...[
                    const SizedBox(height: 8),
                    AuthErrorBanner(mensaje: sesion.errorMessage!),
                  ],

                  const SizedBox(height: 16),

                  PrimaryLoadingButton(
                    label: 'Registrar',
                    isLoading: sesion.isLoading,
                    onPressed: () => _onRegistrarPressed(sesion),
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