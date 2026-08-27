import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_routes.dart';
import '../viewmodels/sesion_viewmodel.dart';
import 'confirmation_dialog.dart';

/// Botón de cerrar sesión con confirmación — EPIC-04 (auditoría UX/UI),
/// resuelve el hallazgo #2 (CRÍTICO): antes, el `IconButton` de logout
/// en las 4 Home cerraba la sesión INMEDIATAMENTE al tocarlo, sin
/// ninguna confirmación — un toque accidental (fácil en un ícono chico
/// de AppBar) desloguea al usuario sin aviso ni forma de deshacerlo.
/// Viola la heurística #3 (control y libertad del usuario) y #5
/// (prevención de errores).
///
/// También resuelve la duplicación mencionada en la propia épica: el
/// mismo bloque de 8 líneas (`IconButton` + `sesion.logout()` +
/// `Navigator.pushReplacementNamed`) estaba copiado, idéntico, en las 4
/// Home views. Ahora hay una sola fuente de verdad.
///
/// Uso — reemplaza directamente el `IconButton` de logout que había en
/// cada Home:
/// ```dart
/// actions: [
///   const LogoutButton(),
/// ],
/// ```
class LogoutButton extends StatelessWidget {
  /// Color del ícono — todas las Home lo usaban blanco (AppBar con
  /// fondo de color), así que ese es el default; se deja overridable
  /// por si alguna pantalla futura tiene un AppBar claro.
  final Color iconColor;

  const LogoutButton({super.key, this.iconColor = Colors.white});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.logout, color: iconColor),
      tooltip: 'Cerrar sesión',
      onPressed: () => _confirmarYCerrarSesion(context),
    );
  }

  Future<void> _confirmarYCerrarSesion(BuildContext context) async {
    final confirmado = await ConfirmationDialog.show(
      context,
      title: '¿Cerrar sesión?',
      message: 'Vas a salir de tu cuenta. Vas a necesitar iniciar sesión '
          'de nuevo para volver a entrar.',
      confirmText: 'Cerrar sesión',
      isDangerous: true,
    );

    if (!confirmado || !context.mounted) return;

    // Alcance de esta épica: NO se toca sesion.logout() (el mecanismo)
    // ni ningún contrato de backend — solo se antepone la confirmación
    // antes de invocarlo, exactamente como pide la épica.
    final sesion = context.read<SesionViewModel>();
    await sesion.logout();

    if (context.mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.roleSelection);
    }
  }
}