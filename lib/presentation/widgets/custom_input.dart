import 'package:flutter/material.dart';
import '../../core/colores_app.dart';

class CustomInput extends StatelessWidget {
  final String hintText;
  final IconData icon;
  final bool isPassword;
  final TextEditingController? controller;

  const CustomInput({
    super.key,
    required this.hintText,
    required this.icon,
    this.controller,
    this.isPassword = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      // hintText (a diferencia de labelText) desaparece visualmente al
      // escribir, y su anuncio para lectores de pantalla una vez el campo
      // tiene contenido no es consistente entre plataformas. Este
      // Semantics explícito fija el nombre accesible del campo
      // ("¿qué es esto?") de forma persistente, sin cambiar el diseño
      // visual existente (mantener labelText habría requerido rediseñar
      // todos los CustomInput del proyecto — fuera de alcance de este
      // ítem, que es puramente de accesibilidad).
      child: Semantics(
        label: hintText,
        child: TextField(
          controller: controller ?? TextEditingController(),
          obscureText: isPassword,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(icon, color: AppColors.verdeClaro),
            suffixIcon: isPassword ? Icon(Icons.visibility_off_outlined) : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
          ),
        ),
      ),
    );
  }
}