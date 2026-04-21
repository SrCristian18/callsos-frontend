import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/colores_app.dart';
import '../viewmodels/login_viewmodel.dart';
import '../widgets/custom_input.dart';

class LoginView extends StatefulWidget {
  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<LoginViewModel>(context);

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: AppColors.negroTexto),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(height: 40),
              const Text(
                "¡Bienvenido!",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.verdeOscuro),
              ),
              const Text(
                "Denunciante",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w300, color: AppColors.negroTexto),
              ),
              const SizedBox(height: 50),
              
              CustomInput(
                hintText: "Nombre de usuario o Email",
                icon: Icons.person_outline,
                controller: viewModel.userController,
              ),
              CustomInput(
                hintText: "Contraseña",
                icon: Icons.lock_outline,
                isPassword: true,
                controller: viewModel.passwordController,
              ),
              
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: const Text("¿Has olvidado tu contraseña?", style: TextStyle(color: AppColors.verdeClaro)),
                ),
              ),
              const SizedBox(height: 30),
              
              // Botón de Iniciar Sesión
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.negroTexto, // El color oscuro de tus botones
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: () => viewModel.login(context),
                  child: const Text("Iniciar Sesión", style: TextStyle(color: Colors.white, fontSize: 18)),
                ),
              ),
              
              const SizedBox(height: 80),
              Center(
                child: Column(
                  children: [
                    const Text("¿Todavía no tienes una cuenta?"),
                    TextButton(
                      onPressed: () {},
                      child: const Text("Regístrate ahora", style: TextStyle(color: AppColors.verdeOscuro, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}