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
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0, 
        leading: IconButton(
          icon: const Icon (Icons.arrow_back_ios_new, color: AppColors.verdeOscuro), 
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.shield, size: 80, color: AppColors.verdeOscuro),
            const SizedBox(height: 20),
            const Text("Acceso oficial", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const Text("Personal de seguridad / CAI"),
            const SizedBox(height: 20),
            
            CustomInput(
              hintText: "Número de placa",
              icon: Icons.badge_outlined,
              controller: viewModel.userController,
            ),
            
            CustomInput(
              hintText: "Contraseña",
              icon: Icons.vpn_key_outlined,
              isPassword: true,
              controller: viewModel.passwordController,
            ),
            
            const SizedBox(height: 10),
            
            viewModel.isLoading 
              ? const CircularProgressIndicator()
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B2A3B), // Un azul oscuro para dar seriedad
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  onPressed: () => viewModel.login(context),
                  child: const Text("Iniciar sesión", style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 14),
            
            //Recuperar contraseña
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: () {},
                child: const Text("¿Has olvidado tu contraseña?", style: TextStyle(color: AppColors.verdeClaro)),
              ),
            ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}