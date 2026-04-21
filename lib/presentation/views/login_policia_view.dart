import 'package:flutter/material.dart';
import '../../core/colores_app.dart';
import '../viewmodels/login_viewmodel.dart';
import '../widgets/custom_input.dart';
import 'package:provider/provider.dart';

class LoginPoliciaView extends StatelessWidget {
  const LoginPoliciaView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<LoginViewModel>(context);

    return Scaffold(
      backgroundColor: AppColors.blancoVerde,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.shield, size: 80, color: AppColors.verdeOscuro),
            const SizedBox(height: 20),
            const Text("ACCESO OFICIAL", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const Text("Personal de Seguridad / CAI"),
            const SizedBox(height: 40),
            
            CustomInput(
              hintText: "Número de Placa o Usuario",
              icon: Icons.badge_outlined,
              controller: viewModel.userController,
            ),
            
            CustomInput(
              hintText: "Contraseña Institucional",
              icon: Icons.vpn_key_outlined,
              isPassword: true,
              controller: viewModel.passwordController,
            ),
            
            const SizedBox(height: 30),
            
            viewModel.isLoading 
              ? const CircularProgressIndicator()
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B2A3B), // Un azul oscuro para dar seriedad
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  onPressed: () => viewModel.login(context),
                  child: const Text("INGRESAR AL SISTEMA", style: TextStyle(color: Colors.white)),
                ),
          ],
        ),
      ),
    );
  }
}