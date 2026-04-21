import 'package:CallSos/presentation/viewmodels/login_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/colores_app.dart';

class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final String role = ModalRoute.of(context)!.settings.arguments as String; //de aqui está tomando el valor del rol

    return Scaffold(
      backgroundColor: AppColors.blancoVerde,
      // Usamos SafeArea para que el botón no quede debajo de la barra de estado (hora/batería)
      body: SafeArea( 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // Alinea el botón a la izquierda
          children: [
            // BOTÓN DE REGRESO
            Padding(
              padding: const EdgeInsets.only(left: 10, top: 10),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.verdeOscuro),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(30.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.security, size: 80, color: AppColors.verdeOscuro), //aqui va el logo.png del proyecto
                    const SizedBox(height: 20),
                    Text(
                      "Hola, ${role.toUpperCase()}",
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const Text("Bienvenido a CALL SOS", textAlign: TextAlign.center),
                    
                    const SizedBox(height: 50),
                    
                    // Botón Iniciar Sesión
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.verdeOscuro,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      ),
                      onPressed: () {
                        Provider.of<LoginViewModel>(context, listen: false).resetForm();
                        if(role == 'policia') Navigator.pushNamed(context, '/login_policia');
                        else Navigator.pushNamed(context, '/login_denunciante');
                      },
                      child: const Text("Iniciar sesion", style: TextStyle(color: Colors.white)),
                    ),
                      
                      const SizedBox(height: 10),

                    // Boton registrarse
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      ),
                      onPressed: () {
                        Provider.of<LoginViewModel>(context, listen: false).resetForm();
                        if(role == 'policia') Navigator.pushNamed(context, '/register_policia');
                        else Navigator.pushNamed(context, '/register_denunciante');
                      },
                      child: const Text("Registrarse", style: TextStyle(color: Color(0xFF1B2A3B), fontWeight: FontWeight.bold)),
                    ),
            const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}