import 'package:flutter/material.dart';

import '../../core/app_routes.dart';
import '../../core/colores_app.dart';
import '../../data/models/enums/rol.dart';
import 'logout_button.dart';

/// AppBar unificado para las 4 Home views — EPIC-06 (auditoría UX/UI).
///
/// Resuelve el hallazgo #6: antes, cada Home construía su propio
/// `AppBar` a mano, y el color de fondo NO tenía una fuente de verdad
/// consistente:
/// - `home_denunciante_view` → `AppColors.verdeOscuro` (bien).
/// - `home_agente_view` → `AppColors.negroTexto`.
/// - `home_comando_view` → `AppColors.negroTexto` — **el mismo color
///   que Agente**. Un usuario que use ambos roles (o vea capturas de
///   ambos) no puede distinguirlos por color — viola la heurística #2
///   (correspondencia con el mundo real: cada rol debería "sentirse"
///   distinto).
/// - `home_cai_view` → `Colors.green.shade700` — ni siquiera pasa por
///   `AppColors`, es un verde de Material escrito a mano, sin relación
///   con la paleta de marca.
///
/// `RoleHeader` resuelve su propio color de acento a partir de [rol],
/// consumiendo la paleta por rol que EPIC-01 ya había definido en
/// `AppColors` (`acentoDenunciante/Agente/OperadorCai/Comando`) pero que
/// hasta esta épica ningún AppBar consumía todavía.
///
/// También incluye el [LogoutButton] (con confirmación, EPIC-04)
/// siempre al final de las acciones — ninguna Home necesita agregarlo
/// por su cuenta.
///
/// Desde EPIC-08 (Ajustes/Configuración) también incluye SIEMPRE, justo
/// antes del [LogoutButton], el ícono de entrada a `AjustesView` — es
/// el único punto de acceso a esa pantalla en toda la app, y al vivir
/// acá (igual que el logout) las 4 Home lo obtienen automáticamente sin
/// tener que agregarlo cada una por su cuenta (criterio de terminado de
/// la épica: "los 4 roles acceden a Ajustes desde su header").
///
/// Implementa [PreferredSizeWidget] (igual que `AppBar`) para poder
/// usarse directamente como `Scaffold.appBar:`, incluyendo el alto
/// extra de [bottom] cuando se provee (ej. el `TabBar` de CAI/Comando).
///
/// Uso:
/// ```dart
/// Scaffold(
///   appBar: RoleHeader(
///     rol: Rol.DENUNCIANTE,
///     titulo: 'CallSOS',
///     subtitulo: sesion.nombreMostrar,
///   ),
///   ...
/// )
///
/// // Con acciones extra (ej. Comando) y TabBar (ej. CAI/Comando):
/// Scaffold(
///   appBar: RoleHeader(
///     rol: Rol.COMANDO,
///     titulo: 'Centro de Comando',
///     subtitulo: sesion.nombreMostrar,
///     extraActions: [
///       IconButton(icon: ..., onPressed: ...),
///     ],
///     bottom: TabBar(controller: _tabs, tabs: const [...]),
///   ),
///   ...
/// )
/// ```
class RoleHeader extends StatelessWidget implements PreferredSizeWidget {
  final Rol rol;
  final String titulo;
  final String subtitulo;

  /// Acciones adicionales, ANTES del [LogoutButton] (que siempre va al
  /// final). Ej: el botón "Generar invitación de agente" de Comando.
  final List<Widget> extraActions;

  /// Ej. el `TabBar` de CAI/Comando. `null` (default) para Denunciante
  /// y Agente, que no tienen tabs.
  final PreferredSizeWidget? bottom;

  const RoleHeader({
    super.key,
    required this.rol,
    required this.titulo,
    required this.subtitulo,
    this.extraActions = const [],
    this.bottom,
  });

  /// Única fuente de verdad del color de acento por rol — consume
  /// directamente la paleta de `AppColors` (EPIC-01). Ningún otro
  /// lugar de la app debería decidir este color por su cuenta.
  Color get _colorAcento => switch (rol) {
        Rol.DENUNCIANTE => AppColors.acentoDenunciante,
        Rol.AGENTE => AppColors.acentoAgente,
        Rol.OPERADOR_CAI => AppColors.acentoOperadorCai,
        Rol.COMANDO => AppColors.acentoComando,
      };

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: _colorAcento,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          Text(
            subtitulo,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
      actions: [
        ...extraActions,
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Colors.white),
          tooltip: 'Ajustes',
          onPressed: () => Navigator.pushNamed(context, AppRoutes.ajustes),
        ),
        const LogoutButton(),
      ],
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );
}