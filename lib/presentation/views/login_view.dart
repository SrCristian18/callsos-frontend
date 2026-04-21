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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              const Text(
                "Bienvenido",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.verdeOscuro),
              ),
              const Text(
                "Denunciante",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w300, color: AppColors.negroTexto),
              ),
              const SizedBox(height: 20),
              
              CustomInput(
                hintText: "Email",
                icon: Icons.person_outline,
                controller: viewModel.userController,
              ),
              CustomInput(
                hintText: "Contraseña",
                icon: Icons.lock_outline,
                isPassword: true,
                controller: viewModel.passwordController,
              ),
              const SizedBox(height: 10),
              
              // Botón de Iniciar Sesión
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.negroTexto, // El color oscuro de tus botones
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: () => viewModel.login(context),
                  child: const Text("Iniciar sesión", style: TextStyle(color: Colors.white, fontSize: 18)),
                ),
              ),
              const SizedBox(height: 14),



              //Recuperar contraseña
            Center(
              child: MouseRegion(
                cursor: SystemMouseCursors.click, // Esto pone la "manito" al pasar el mouse
                child: InkWell(
                  borderRadius: BorderRadius.circular(5), // Para que el efecto visual no sea cuadrado
                  onTap: () => Navigator.pushNamed(context, '/forgot_password'),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0), // Aumenta el área de clic
                    child: Text(
                      "¿Has olvidado tu contraseña?",
                      style: TextStyle(
                        color: const Color(0xFF4CAF50), // Tu verde esmeralda
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
          ),
        ),
      ),
    ),
  ),
),




            ],
          ),
        ),
      ),
    );
  }
}