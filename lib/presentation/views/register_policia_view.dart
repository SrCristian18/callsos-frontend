import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/custom_input.dart';
import '../../core/colores_app.dart';
import '../viewmodels/register_policia_viewmodel.dart';

class RegisterPoliciaView extends StatelessWidget {
  const RegisterPoliciaView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<RegisterPoliciaViewModel>(context);

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
            
            const SizedBox(height: 15),
            
            // SECCIÓN DE TOKEN
            if (!viewModel.isTokenRequested)
              ElevatedButton.icon(
                onPressed: viewModel.isLoading ? null : () => viewModel.solicitarToken(),
                icon: viewModel.isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
                label: const Text("Solicitar Token al Comando"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800),
              )
            else if (!viewModel.isTokenValidated)
              Row(
                children: [
                  Expanded(
                    child: CustomInput(
                      hintText: 'Ingresar Token', 
                      icon: Icons.vpn_key,
                      controller: viewModel.tokenController,
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    onPressed: () => viewModel.validarToken(),
                    icon: const Icon(Icons.check),
                    style: IconButton.styleFrom(backgroundColor: AppColors.verdeOscuro),
                  )
                ],
              )
            else
              const Row(
                children: [
                  Icon(Icons.verified, color: Colors.green),
                  SizedBox(width: 10),
                  Text("Token Validado correctamente", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ],
              ),

            const SizedBox(height: 20),
            
            // CAMPOS DE CONTRASEÑA (Habilitados solo si el token es válido)
            Opacity(
              opacity: viewModel.isTokenValidated ? 1.0 : 0.5,
              child: AbsorbPointer(
                absorbing: !viewModel.isTokenValidated,
                child: Column(
                  children: [
                    CustomInput(
                      hintText: 'Contraseña', 
                      icon: Icons.lock, 
                      isPassword: true,
                      controller: viewModel.passwordController,
                    ),
                    CustomInput(
                      hintText: 'Confirmar contraseña', 
                      icon: Icons.lock_clock, 
                      isPassword: true,
                      controller: viewModel.confirmPasswordController,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: viewModel.isTokenValidated 
                    ? const Color(0xFF1B2A3B) 
                    : Colors.grey,
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