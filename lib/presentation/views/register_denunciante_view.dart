import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/app_routes.dart';
import '../../core/colores_app.dart';
import '../../data/models/enums/rol.dart';
import '../../data/services/notificacion_service.dart';
import '../viewmodels/sesion_viewmodel.dart';
import '../widgets/app_password_field.dart';
import '../widgets/custom_input.dart';

/// Registro de denunciante.
///
/// FIX (Épica 2, punto 3 — deuda_backend.md): antes era un mockup estático
/// sin ningún TextEditingController ni lógica de envío (`onPressed: () {}`).
/// Ahora conecta con [SesionViewModel.registrarDenunciante] — mismo patrón
/// que [LoginView], con autologueo tras un registro exitoso.
///
/// No hay campo "usuario" separado: se usa "documento" como username de
/// login (ver nota de diseño en RegistrarDenunciantePort, backend).
class RegisterDenuncianteView extends StatefulWidget {
  const RegisterDenuncianteView({super.key});

  @override
  State<RegisterDenuncianteView> createState() =>
      _RegisterDenuncianteViewState();
}

class _RegisterDenuncianteViewState extends State<RegisterDenuncianteView> {
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _documentoController = TextEditingController();
  final _celularController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmarPasswordController = TextEditingController();

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _documentoController.dispose();
    _celularController.dispose();
    _passwordController.dispose();
    _confirmarPasswordController.dispose();
    super.dispose();
  }

  bool get _camposCompletos =>
      _nombreController.text.isNotEmpty &&
      _apellidoController.text.isNotEmpty &&
      _documentoController.text.isNotEmpty &&
      _celularController.text.isNotEmpty &&
      _passwordController.text.isNotEmpty &&
      _confirmarPasswordController.text.isNotEmpty;

  Future<void> _onRegistrarPressed(SesionViewModel sesion) async {
    if (!_camposCompletos) return;

    final exito = await sesion.registrarDenunciante(
      nombre: _nombreController.text.trim(),
      apellido: _apellidoController.text.trim(),
      documento: _documentoController.text.trim(),
      telefono: _celularController.text.trim(),
      password: _passwordController.text,
      confirmarPassword: _confirmarPasswordController.text,
    );

    if (exito && mounted) {
      // Mismo criterio que LoginView tras un login exitoso.
      if (AppConfig.firebaseHabilitado && sesion.rol == Rol.DENUNCIANTE) {
        context.read<NotificacionService>().registrarTokenEnBackend(
              actorId: sesion.actorId!,
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
                  const Icon(Icons.person_add_alt_1,
                      size: 70, color: AppColors.verdeOscuro),
                  const SizedBox(height: 16),
                  const Text(
                    'Crear cuenta',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Regístrate para reportar emergencias'),
                  const SizedBox(height: 24),

                  CustomInput(
                    hintText: 'Nombre',
                    icon: Icons.badge_outlined,
                    controller: _nombreController,
                  ),
                  CustomInput(
                    hintText: 'Apellido',
                    icon: Icons.badge_outlined,
                    controller: _apellidoController,
                  ),
                  CustomInput(
                    hintText: 'Documento de identidad',
                    icon: Icons.credit_card,
                    controller: _documentoController,
                  ),
                  CustomInput(
                    hintText: 'Celular',
                    icon: Icons.phone_outlined,
                    controller: _celularController,
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
                    Text(
                      sesion.errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  const SizedBox(height: 16),

                  sesion.isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.verdeOscuro,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25)),
                          ),
                          onPressed: () => _onRegistrarPressed(sesion),
                          child: const Text('Registrar',
                              style: TextStyle(color: Colors.white)),
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