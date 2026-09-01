import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_config.dart';
import '../../core/app_routes.dart';
import '../../core/colores_app.dart';
import '../../data/models/enums/rol.dart';
import '../viewmodels/sesion_viewmodel.dart';
import '../viewmodels/theme_viewmodel.dart';
import '../widgets/confirmation_dialog.dart';

/// Pantalla de Ajustes / Configuración.
///
/// EPIC-08 (Design System, auditoría UX/UI) — resuelve el hallazgo #3:
/// la app no tenía ningún lugar central donde el usuario pudiera elegir
/// su tema, ver quién había iniciado sesión, o encontrar la versión
/// instalada. Heurísticas #3 (control y libertad del usuario — el tema
/// deja de ser una decisión implícita del sistema operativo) y #10
/// (ayuda y documentación — la versión queda siempre visible).
///
/// Alcance de ESTA épica (ver "No modificar" de EPIC-08): NADA de lo de
/// acá agrega una configuración nueva que dependa del backend.
/// - El selector de tema es un override MANUAL sobre el mecanismo que
///   ya existe en [ThemeViewModel] (EPIC-02) — esta vista no reimplementa
///   persistencia, solo llama [ThemeViewModel.cambiarTema].
/// - Los datos de cuenta (nombre, rol) ya están disponibles en
///   [SesionViewModel] — no se pide nada nuevo al backend.
/// - Cerrar sesión reutiliza el mismo [ConfirmationDialog] que
///   [LogoutButton] (EPIC-04), para no tener dos textos/comportamientos
///   distintos de la misma acción en la app.
///
/// Punto de entrada: el ícono nuevo en `RoleHeader` (EPIC-06), presente
/// en las 4 Home — ver criterio de terminado de la épica.
class AjustesView extends StatelessWidget {
  const AjustesView({super.key});

  @override
  Widget build(BuildContext context) {
    final sesion = context.watch<SesionViewModel>();
    final temaVm = context.watch<ThemeViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes'),
        backgroundColor: AppColors.negroTexto,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SeccionCuenta(sesion: sesion),
          const SizedBox(height: 24),
          _SeccionTema(temaActual: temaVm.themeMode, onCambiar: temaVm.cambiarTema),
          const SizedBox(height: 24),
          _BotonCerrarSesion(sesion: sesion),
          const SizedBox(height: 24),
          const _SeccionVersion(),
        ],
      ),
    );
  }
}

/// Encabezado visual reutilizado por cada sección — mismo título
/// pequeño en mayúsculas + tarjeta blanca debajo, para que las 3
/// secciones se vean como parte de un mismo sistema.
class _TituloSeccion extends StatelessWidget {
  final String texto;
  const _TituloSeccion(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        texto.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7) ??
              Colors.grey,
        ),
      ),
    );
  }
}

class _SeccionCuenta extends StatelessWidget {
  final SesionViewModel sesion;
  const _SeccionCuenta({required this.sesion});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _TituloSeccion('Cuenta'),
        Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(
              sesion.nombreMostrar,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(sesion.rol?.etiqueta ?? ''),
          ),
        ),
      ],
    );
  }
}

class _SeccionTema extends StatelessWidget {
  final ThemeMode temaActual;
  final ValueChanged<ThemeMode> onCambiar;

  const _SeccionTema({required this.temaActual, required this.onCambiar});

  static const _opciones = [
    (ThemeMode.system, 'Igual que el sistema', Icons.brightness_auto),
    (ThemeMode.light, 'Claro', Icons.light_mode_outlined),
    (ThemeMode.dark, 'Oscuro', Icons.dark_mode_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _TituloSeccion('Tema'),
        Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          // `RadioGroup` (API vigente desde Flutter 3.32) reemplaza a los
          // `groupValue`/`onChanged` individuales de cada RadioListTile
          // (deprecados) — un solo lugar decide el valor seleccionado y
          // qué pasa cuando cambia, para todos los Radio hijos.
          child: RadioGroup<ThemeMode>(
            groupValue: temaActual,
            onChanged: (nuevo) {
              if (nuevo != null) onCambiar(nuevo);
            },
            child: Column(
              children: [
                for (final (modo, etiqueta, icono) in _opciones)
                  RadioListTile<ThemeMode>(
                    value: modo,
                    secondary: Icon(icono),
                    title: Text(etiqueta),
                    activeColor: AppColors.verdeOscuro,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BotonCerrarSesion extends StatelessWidget {
  final SesionViewModel sesion;
  const _BotonCerrarSesion({required this.sesion});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.logout, color: AppColors.error),
        title: const Text('Cerrar sesión', style: TextStyle(color: AppColors.error)),
        onTap: () => _confirmarYCerrarSesion(context),
      ),
    );
  }

  /// Mismo diálogo y mismo texto que [LogoutButton] (EPIC-04) — una
  /// sola fuente de verdad de "qué significa cerrar sesión" en toda la
  /// app, aunque el punto de entrada visual sea distinto acá.
  ///
  /// A diferencia de [LogoutButton] (que usa `pushReplacementNamed`
  /// porque vive en la raíz de cada Home), acá usamos
  /// `pushNamedAndRemoveUntil`: AjustesView está APILADA sobre una Home,
  /// así que un simple replace dejaría esa Home todavía en el stack,
  /// debajo de la pantalla de selección de rol — permitiendo volver
  /// atrás hacia una sesión que ya no existe.
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

    await sesion.logout();

    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.roleSelection,
        (route) => false,
      );
    }
  }
}

class _SeccionVersion extends StatelessWidget {
  const _SeccionVersion();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'CallSOS · v${AppConfig.appVersion}',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6) ??
              Colors.grey,
        ),
      ),
    );
  }
}