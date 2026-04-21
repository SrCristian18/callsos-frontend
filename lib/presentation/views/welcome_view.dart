import 'package:flutter/material.dart';
import '../../core/colores_app.dart';

class WelcomeView extends StatelessWidget {
  const WelcomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final String role = ModalRoute.of(context)!.settings.arguments as String;

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
                onPressed: () => Navigator.pop(context), // <--- Esta es la función mágica
              ),
            ),
            
            // EL RESTO DEL CONTENIDO
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(30.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.security, size: 80, color: AppColors.verdeOscuro),
                    const SizedBox(height: 20),
                    Text(
                      "HOLA, ${role.toUpperCase()}",
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const Text("Bienvenido a CALL S.O.S", textAlign: TextAlign.center),
                    const SizedBox(height: 50),
                    
                    // Botón Iniciar Sesión
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.verdeOscuro,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      ),
                      onPressed: () {
                        if(role == 'policia') Navigator.pushNamed(context, '/login_policia');
                        else Navigator.pushNamed(context, '/login_denunciante');
                      },
                      child: const Text("YA TENGO CUENTA", style: TextStyle(color: Colors.white)),
                    ),
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