import 'package:flutter/material.dart';

/// Estado "sin datos" reutilizable — EPIC-03 (Design System, auditoría
/// UX/UI).
///
/// Extrae el bloque ícono+mensaje que hoy se repite en
/// `incidente_list_body.dart` (lista vacía de incidentes). Desde
/// EPIC-07 también lo usa `Timeline` (tab "Historial" de
/// `DetalleIncidenteView`) cuando un incidente todavía no tiene eventos
/// de auditoría registrados.
///
/// Uso:
/// ```dart
/// if (incidentes.isEmpty) {
///   return const EmptyState(
///     icon: Icons.inbox_outlined,
///     message: 'No hay incidentes disponibles.',
///   );
/// }
/// ```
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  /// Texto secundario opcional, más chico, debajo del mensaje principal
  /// (ej. una sugerencia de qué hacer — "Tocá + para reportar uno").
  final String? subtitle;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}