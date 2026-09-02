import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_routes.dart';
import '../../core/colores_app.dart';
import '../../data/models/enums/rol.dart';
import '../viewmodels/sesion_viewmodel.dart';
import '../widgets/app_password_field.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/custom_input.dart';
import '../widgets/primary_loading_button.dart';

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
/// - En éxito, el JWT queda persistido (F.0.4) y se navega a la Home real
///   correspondiente al rol (F.2): HomeAgenteView, HomeCAIView o
///   HomeComandoView (ver [_rutaPorRol]).
///
/// La reescritura visual completa (rediseño, textos, validaciones de
/// formulario) es alcance de F.1/F.2; este cambio se limita a conectar la
/// funcionalidad de sesión.
///
/// EPIC-13 (Design System, auditoría UX/UI) — error y botón de carga
/// migrados a [AuthErrorBanner]/[PrimaryLoadingButton] (ver
/// docstrings), unificando el tratamiento visual con [LoginView],
/// [RegisterDenuncianteView] y [RegisterPoliciaView].
class LoginPoliciaView extends StatefulWidget {
  const LoginPoliciaView({super.key});

  @override
  State<LoginPoliciaView> createState() => _LoginPoliciaViewState();
}

class _LoginPoliciaViewState extends State<LoginPoliciaView> {
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();

  /// Home correspondiente al rol autenticado.
  /// Mismo patrón que `SplashView._rutaPorRol` (F.0.5) — los roles
  /// policiales (AGENTE / OPERADOR_CAI / COMANDO) van cada uno a su
  /// Home real (F.2), no a la ruta legacy '/incident_view'.
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
      // FIX (validación end-to-end): este login llevaba a la ruta legacy
      // '/incident_view' (comando_widget/jefecai_widget/agente_widget —
      // datos mock en memoria, sin conexión real al backend). Las Home
      // views reales (F.2) ya existen y deben usarse en su lugar.
      Navigator.pushReplacementNamed(context, _rutaPorRol(sesion.rol!));
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

                  AppPasswordField(
                    hintText: "Contraseña",
                    icon: Icons.vpn_key_outlined,
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
                    backgroundColor: AppColors.negroTexto,
                    onPressed: () => _onLoginPressed(sesion),
                  ),
                  const SizedBox(height: 14),

                  // Recuperar contraseña
                  //
                  // Bloque 3 (Épica 8) — este link es el mismo patrón que
                  // "¿Olvidaste tu contraseña?" en LoginView (citizen),
                  // pero usaba Color(0xFF4CAF50) (verde Material estándar,
                  // ningún AppColors coincide) en vez de un verde de marca
                  // — inconsistencia sin intención aparente entre dos
                  // pantallas gemelas. Alineado con AppColors.verdeClaro,
                  // el mismo que usa el link equivalente en LoginView.
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
                              color: AppColors.verdeClaro,
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