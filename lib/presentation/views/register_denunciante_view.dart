import 'package:flutter/material.dart';
import '../../core/colores_app.dart';
import '../widgets/custom_input.dart'; // Asumiendo tu widget personalizado

class RegisterDenuncianteView extends StatelessWidget {
  const RegisterDenuncianteView({super.key});

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              "Registrar denunciante",
              style: TextStyle(
                fontSize: 32, 
                fontWeight: FontWeight.bold, 
                color: Color(0xFF1B2A3B),
                height: 1.1
              ),
            ),
            const SizedBox(height: 10),
            const CustomInput(hintText: 'Nombre', icon: Icons.person),
            const CustomInput(hintText: 'Apellido', icon: Icons.person_outline),
            const CustomInput(hintText: 'Numero de documento de identidad', icon: Icons.badge_outlined),
            const CustomInput(hintText: 'Celular', icon: Icons.phone),
            const CustomInput(hintText: 'Contraseña', icon: Icons.lock_outline, isPassword: true),
            const CustomInput(hintText: 'Confirmar contraseña', icon: Icons.lock_reset, isPassword: true),
            const SizedBox(height: 15),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B2A3B),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              onPressed: () {},
              child: const Text("Registrar", style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 20),
            
            /* Esta funcion sirve para colocar si existen registro anonimos de parte del denunciante
            Center(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: RichText(
                  text: const TextSpan(
                    text: "Registro anonimo ",
                    style: TextStyle(color: Colors.black54),
                    children: [
                      TextSpan(
                        text: "Inicia sesión",
                        style: TextStyle(color: Color(0xFF007A8B), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            */

          ],
        ),
      ),
    );
  }
}