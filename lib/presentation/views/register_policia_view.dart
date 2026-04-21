import 'package:flutter/material.dart';
import '../widgets/custom_input.dart';
import '../../core/colores_app.dart';

class RegisterPoliciaView extends StatelessWidget {
  const RegisterPoliciaView({super.key});

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
              "Registrar Agentes del CAI",
              style: TextStyle(
                fontSize: 32, 
                fontWeight: FontWeight.bold, 
                color: Color(0xFF1B2A3B),
                height: 1.1
              ),
            ),
            const SizedBox(height: 10),
            const CustomInput(hintText: 'Estación', icon: Icons.local_police),
            const CustomInput(hintText: 'Nombre del CAI', icon: Icons.home_work),
            const CustomInput(hintText: 'Dirección', icon: Icons.location_on),
            const CustomInput(hintText: 'Nombre del Agente', icon: Icons.person),
            const CustomInput(hintText: 'Número de placa', icon: Icons.badge),
            const CustomInput(hintText: 'Número de celular', icon: Icons.phone_android),
            const CustomInput(hintText: 'Contraseña', icon: Icons.lock, isPassword: true),
            const CustomInput(hintText: 'Confirmar contraseña', icon: Icons.lock_clock, isPassword: true),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B2A3B),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              onPressed: () {},
              child: const Text("Registrar", style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }
}