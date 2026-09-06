import 'package:flutter/material.dart';

import '../../core/app_radius.dart';
import '../../core/colores_app.dart';

/// Campo de texto reutilizable — EPIC-03 (Design System, auditoría UX/UI).
///
/// Sucesor de `CustomInput` para campos que NO son de contraseña (para
/// eso está [AppPasswordField]) — `CustomInput` no se borra en esta
/// épica, coexiste hasta que EPIC-04 migre cada uso.
///
/// Diferencias deliberadas frente a `CustomInput`:
/// - Usa `TextFormField` (no `TextField`) — habilita [validator] y
///   participa en un `Form` ascendente si existe. `CustomInput` no
///   soporta validación en absoluto hoy; cada vista que necesita
///   validar contraseñas/campos lo hace por fuera, a mano.
/// - Radio `AppRadius.sm` (12) en vez del `15` hardcodeado de
///   `CustomInput` — alineado a la escala de EPIC-01. Diferencia visual
///   mínima (3px) y sin efecto hoy: este componente no está conectado a
///   ninguna vista todavía.
/// - Acepta [errorText]/[validator] y refleja el estado de error con el
///   color semántico `AppColors.error` (heurística #5, prevención de
///   errores — el campo con error se distingue visualmente sin esperar
///   a que el usuario intente enviar el formulario).
///
/// Uso:
/// ```dart
/// AppTextField(
///   controller: _emailController,
///   hintText: 'Correo electrónico',
///   icon: Icons.email_outlined,
///   keyboardType: TextInputType.emailAddress,
///   validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
/// )
/// ```
class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final IconData? icon;
  final String? errorText;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onFieldSubmitted;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final int maxLines;
  final bool enabled;
  final bool autofocus;

  const AppTextField({
    super.key,
    required this.hintText,
    this.controller,
    this.icon,
    this.errorText,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.maxLines = 1,
    this.enabled = true,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    // Mismo Semantics explícito que CustomInput, mismo motivo: hintText
    // no es un nombre accesible persistente por sí solo.
    //
    // EPIC-19 (verificación de accesibilidad) — CONFIRMADO, no solo
    // inferido: se probó sacar `excludeSemantics` (la documentación de
    // Flutter y una regla de lint de la comunidad sugerían que el
    // patrón sin excludeSemantics era el correcto) y el resultado real
    // en `flutter test` fue peor de lo que EPIC-14 sospechaba — no es
    // que el label se duplique, es que DESAPARECE por completo
    // (`find.bySemanticsLabel('...')` pasa a devolver 0 coincidencias,
    // no 2). O sea: sin `excludeSemantics`, este campo se queda SIN
    // ningún nombre accesible. Revertido — se queda con
    // `excludeSemantics: true`. Documentación cerrada con evidencia de
    // verdad, no con una suposición.
    return Semantics(
      label: hintText,
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: enabled ? Colors.white : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: errorText != null
              ? Border.all(color: AppColors.error, width: 1.4)
              : null,
          boxShadow: errorText == null
              ? const [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: Offset(0, 2)),
                ]
              : null,
        ),
        child: TextFormField(
          controller: controller,
          enabled: enabled,
          autofocus: autofocus,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          maxLines: maxLines,
          // `validator` sigue disponible para uso dentro de un `Form`
          // ascendente (EPIC-04 puede necesitarlo) — pero el borde rojo
          // y el mensaje que se ven en pantalla los controla SIEMPRE
          // [errorText] (arriba, en el Container, y abajo, en
          // decoration.errorText), no el resultado interno del
          // validator. Este componente está pensado para el patrón que
          // ya usa el resto de la app (validar a mano, mostrar el
          // resultado vía un campo de estado en el ViewModel/vista, ej.
          // `ApiException.message`), no para `Form.validate()`
          // disparando su propio texto de error por separado — mezclar
          // ambos mecanismos a la vez mostraría el error duplicado.
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          decoration: InputDecoration(
            hintText: hintText,
            errorText: errorText,
            prefixIcon:
                icon != null ? Icon(icon, color: AppColors.verdeClaro) : null,
            border: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            errorStyle: const TextStyle(color: AppColors.error, fontSize: 12),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
          ),
        ),
      ),
    );
  }
}