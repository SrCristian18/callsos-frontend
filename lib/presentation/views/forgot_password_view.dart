import 'package:CallSos/core/colores_app.dart';
import 'package:flutter/material.dart';
import '../widgets/custom_input.dart';

class ForgotPasswordView extends StatelessWidget {
  const ForgotPasswordView({super.key});

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
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 50),
            const Text(
              "¿Olvidaste tu contraseña?",
              style: TextStyle(
                fontSize: 32, 
                fontWeight: FontWeight.bold, 
                color: Color(0xFF1B2A3B),
                height: 1.1
              ),
            ),
            const SizedBox(height: 10),
            const CustomInput(hintText: 'Ingrese su dirección de correo', 
              icon: Icons.email_outlined
            ),
            const SizedBox(height: 12),
            const Text(
              "Le llegará un correo recuperar su contraseña",
              style: TextStyle(color: AppColors.verdeClaro, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B2A3B),
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                onPressed: () {
                  // Aquí iría la lógica para enviar el correo

                  //se vuelve al login
                  Navigator.pop(context);
                },
                child: const Text("Enviar", style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}