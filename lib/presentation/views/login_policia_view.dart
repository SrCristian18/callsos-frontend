import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/colores_app.dart';
import '../viewmodels/sesion_viewmodel.dart';
import '../widgets/custom_input.dart';

/// Login de roles policiales (Agente, Operador CAI, Comando).
///
/// F.0.4 — Gestión de sesión.
///
/// Antes esta vista usaba `LoginViewModel` (mock con `Future.delayed`, sin
/// red ni persistencia — ver diagnóstico inicial). Ahora:
///
/// - Llama a [SesionViewModel.login] -> `POST /auth/login` (F.0.3).
/// - Muestra [SesionViewModel.errorMessage] si falla (credenciales
///   inválidas, timeout, sin conexión — ver `ApiException`).
/// - En éxito, el JWT queda persistido (F.0.4) y se navega a
///   `/incident_view` (que despacha por rol — Comando/Operador CAI/Agente).
///
/// La reescritura visual completa (rediseño, textos, validaciones de
/// formulario) es alcance de F.1/F.2; este cambio se limita a conectar la
/// funcionalidad de sesión.
class LoginPoliciaView extends StatefulWidget {
  const LoginPoliciaView({super.key});

  @override
  State<LoginPoliciaView> createState() => _LoginPoliciaViewState();
}

class _LoginPoliciaViewState extends State<LoginPoliciaView> {
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
      // IncidenteView despacha internamente por Rol (Comando / OPERADOR_CAI
      // / AGENTE) — ver F.0.2.
      Navigator.pushReplacementNamed(context, '/incident_view');
    }
    // Si falla, sesion.errorMessage ya quedó seteado y el Consumer de abajo
    // lo muestra automáticamente.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blancoVerde,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.verdeOscuro),
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
                  const Icon(Icons.shield, size: 80, color: AppColors.verdeOscuro),
                  const SizedBox(height: 20),
                  const Text(
                    "Acceso oficial",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text("Personal de seguridad / CAI"),
                  const SizedBox(height: 20),

                  CustomInput(
                    // F.0.4: antes "Número de placa" — el backend autentica
                    // por username (ver seed: "pedro.agente", etc.), no por
                    // número de placa. El rediseño de textos/UX es F.1/F.2.
                    hintText: "Usuario",
                    icon: Icons.badge_outlined,
                    controller: _userController,
                  ),

                  CustomInput(
                    hintText: "Contraseña",
                    icon: Icons.vpn_key_outlined,
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
                            backgroundColor: const Color(0xFF1B2A3B),
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          onPressed: () => _onLoginPressed(sesion),
                          child: const Text(
                            "Iniciar sesión",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                  const SizedBox(height: 14),

                  // Recuperar contraseña
                  Center(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(5),
                        onTap: () => Navigator.pushNamed(context, '/forgot_password'),
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            "¿Has olvidado tu contraseña?",
                            style: TextStyle(
                              color: Color(0xFF4CAF50),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}