import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/app_routes.dart';
import '../../core/colores_app.dart';
import '../../data/models/enums/rol.dart';
import '../../data/services/notificacion_service.dart';
import '../viewmodels/sesion_viewmodel.dart';
import '../widgets/custom_input.dart';

/// Login del denunciante.
///
/// F.5 — conecta con [SesionViewModel] (login real) y registra el token
/// FCM tras el éxito para habilitar notificaciones push del backend.
///
/// La vista anterior usaba [LoginViewModel] (mock). Ahora usa el mismo
/// [SesionViewModel] que [LoginPoliciaView] — mismo patrón, distinta ruta
/// de destino (DENUNCIANTE → [HomeDenuncianteView]).
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
      // F.5 — Registrar token FCM solo si Firebase está habilitado y el
      // rol es DENUNCIANTE (el backend solo usa tokenFcm para denunciantes).
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

                  CustomInput(
                    hintText: 'Contraseña',
                    icon: Icons.lock_outline,
                    isPassword: true,
                    controller: _passwordController,
                  ),

                  if (sesion.errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      sesion.errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  const SizedBox(height: 10),

                  sesion.isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.verdeOscuro,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25)),
                          ),
                          onPressed: () => _onLoginPressed(sesion),
                          child: const Text('Iniciar sesión',
                              style: TextStyle(color: Colors.white)),
                        ),

                  const SizedBox(height: 14),
                  Center(
                    child: InkWell(
                      onTap: () => Navigator.pushNamed(
                          context, AppRoutes.forgotPassword),
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          '¿Olvidaste tu contraseña?',
                          style: TextStyle(
                              color: AppColors.verdeClaro,
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