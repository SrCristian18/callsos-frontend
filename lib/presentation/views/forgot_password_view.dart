import 'package:CallSos/core/colores_app.dart';
import 'package:flutter/material.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/custom_input.dart';

/// Recuperación de contraseña.
///
/// EPIC-13 (Design System, auditoría UX/UI) — "auditar y unificar
/// loading/success/error/empty en TODAS las pantallas restantes":
///
/// REQUIERE CAMBIO DE BACKEND: no existe (todavía) ningún endpoint de
/// recuperación de contraseña — antes, tocar "Enviar" no hacía
/// LITERALMENTE nada (`onPressed: () {}`), sin ningún feedback de
/// ningún tipo. Eso viola la heurística #1 (visibilidad del estado del
/// sistema) y la #9 (ayudar a reconocer/diagnosticar errores) más
/// gravemente que cualquier inconsistencia visual: el usuario no tiene
/// forma de saber si tocó el botón, si está "cargando", si funcionó o
/// si simplemente no existe la función.
///
/// Mismo criterio que EPIC-12 aplicó al tab "Delegados" de Comando
/// (hallazgo #14): mientras no exista el endpoint, la respuesta
/// correcta NO es simular un envío exitoso — es comunicar la
/// limitación con honestidad, usando el mismo canal de feedback que ya
/// usa el resto de la app ([AppSnackBar.advertencia]).
class ForgotPasswordView extends StatelessWidget {
  const ForgotPasswordView({super.key});

  void _onEnviarPressed(BuildContext context) {
    AppSnackBar.advertencia(
      context,
      'La recuperación de contraseña todavía no está disponible. '
      'Contactá a soporte si perdiste el acceso a tu cuenta.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blancoVerde,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.verdeOscuro),
          tooltip: 'Volver',
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
                color: AppColors.negroTexto,
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
              // EPIC-14: verdeClaro (#7EAD1F) da 2.58:1 de contraste
              // sobre blancoVerde — falla AA incluso para texto grande
              // (mínimo 3:1). verdeTexto es el mismo verde, oscurecido
              // para pasar AA (4.63:1), sin tocar el swatch de marca.
              style: TextStyle(color: AppColors.verdeTexto, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.negroTexto,
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                onPressed: () => _onEnviarPressed(context),
                child: const Text("Enviar", style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}