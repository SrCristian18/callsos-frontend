import 'package:flutter/material.dart';

import '../../core/app_radius.dart';
import '../../core/colores_app.dart';

/// Campo de contraseña reutilizable — EPIC-03 (Design System, auditoría
/// UX/UI).
///
/// **Corrige un bug real de `CustomInput`, no solo un rediseño.**
/// `CustomInput(isPassword: true)` es un `StatelessWidget` que:
/// 1. Fija `obscureText: true` de forma permanente (no hay estado que
///    lo cambie).
/// 2. Dibuja un ícono `Icons.visibility_off_outlined` como `suffixIcon`
///    — pero es un `Icon` puro, sin `GestureDetector`/`IconButton`, sin
///    `onPressed`, sin ningún handler. **Tocarlo no hace nada.**
///
/// El resultado: el usuario ve un ícono de "ojo" que parece un control
/// interactivo (misma convención visual que cualquier otro campo de
/// contraseña que haya usado antes), lo toca esperando revisar lo que
/// escribió, y no pasa nada — la contraseña sigue oculta siempre. Viola
/// la heurística #5 (prevención de errores: sin poder verificar lo
/// escrito, un typo en la contraseña solo se descubre cuando el login
/// falla) y #1 (visibilidad del estado: el ícono miente sobre ser
/// interactivo).
///
/// Por eso este componente es `StatefulWidget` — a diferencia de
/// `CustomInput` — con un booleano real (`_obscure`) que el
/// `IconButton` alterna.
///
/// `CustomInput` NO se borra en esta épica — coexiste hasta que EPIC-04
/// migre cada uso (login, registro, cambio de contraseña).
///
/// Uso:
/// ```dart
/// AppPasswordField(
///   controller: _passwordController,
///   hintText: 'Contraseña',
///   validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
/// )
/// ```
class AppPasswordField extends StatefulWidget {
  final TextEditingController? controller;
  final String hintText;
  final IconData icon;
  final String? errorText;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onFieldSubmitted;
  final TextInputAction? textInputAction;
  final bool enabled;
  final bool autofocus;

  const AppPasswordField({
    super.key,
    required this.hintText,
    this.controller,
    this.icon = Icons.lock_outline,
    this.errorText,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.textInputAction,
    this.enabled = true,
    this.autofocus = false,
  });

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  // El toggle real que CustomInput nunca tuvo.
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    // EPIC-19: ver el comentario equivalente en `AppTextField` — se
    // probó y CONFIRMÓ (no solo se infirió) que sacar
    // `excludeSemantics` acá deja al campo sin ningún nombre accesible
    // (`find.bySemanticsLabel` pasa de 1 a 0 coincidencias, no a 2).
    // Revertido. El tooltip del `IconButton` de mostrar/ocultar
    // contraseña de más abajo sigue sin llegar al lector de pantalla
    // mientras este `Semantics` externo lo excluya — pendiente real de
    // resolver, no de este campo puntual (ver
    // docs/verificacion_accesibilidad_manual.md).
    return Semantics(
      label: widget.hintText,
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: widget.enabled ? Colors.white : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: widget.errorText != null
              ? Border.all(color: AppColors.error, width: 1.4)
              : null,
          boxShadow: widget.errorText == null
              ? const [
                  BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: Offset(0, 2)),
                ]
              : null,
        ),
        child: TextFormField(
          controller: widget.controller,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          obscureText: _obscure,
          // Igual que en AppTextField: validator queda disponible para
          // un Form ascendente, pero lo que se VE en pantalla lo
          // controla siempre widget.errorText (mismo motivo, ver
          // AppTextField).
          validator: widget.validator,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onFieldSubmitted,
          textInputAction: widget.textInputAction,
          decoration: InputDecoration(
            hintText: widget.hintText,
            errorText: widget.errorText,
            prefixIcon: Icon(widget.icon, color: AppColors.verdeClaro),
            // EL FIX: IconButton real, con estado real, con Semantics
            // real — no un Icon suelto.
            suffixIcon: IconButton(
              icon: Icon(
                _obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.grey.shade600,
              ),
              tooltip: _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
              onPressed: widget.enabled
                  ? () => setState(() => _obscure = !_obscure)
                  : null,
            ),
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