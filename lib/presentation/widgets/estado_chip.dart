import 'package:flutter/material.dart';

import '../../data/models/enums/estado_incidente.dart';

/// Chip visual que representa el estado actual de un [Incidente].
///
/// F.1 — Widgets base.
///
/// Reemplaza el helper privado `_estadoChip(EstadoIncidente)` que vivía
/// inline en `reporte_view.dart`. Al ser un widget independiente puede
/// reutilizarse en:
/// - [IncidenteCard] (lista de incidentes del denunciante/agente/CAI).
/// - [DetalleIncidenteView] (F.2).
/// - Cualquier lista futura que muestre incidentes.
///
/// Uso:
/// ```dart
/// EstadoChip(estado: incidente.estado)
/// EstadoChip(estado: incidente.estado, compact: true) // punto + texto corto
/// ```
class EstadoChip extends StatelessWidget {
  final EstadoIncidente estado;

  /// Si `true`, muestra una versión compacta (punto de color + texto corto)
  /// apta para espacios reducidos como filas de lista.
  /// Si `false` (por defecto), muestra el chip con fondo de color.
  final bool compact;

  const EstadoChip({
    super.key,
    required this.estado,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = _configPorEstado(estado);

    // Sin este Semantics explícito, un lector de pantalla anuncia solo la
    // etiqueta suelta ("Creado", "Cancelado"...) sin contexto de que es
    // el ESTADO del incidente — y en el modo compacto, el punto de color
    // es puramente decorativo (no comunica nada por sí solo a un lector
    // de pantalla ni a un usuario daltónico). `excludeSemantics: true`
    // evita que el Text hijo se anuncie una segunda vez por separado.
    return Semantics(
      label: 'Estado del incidente: ${config.etiqueta}',
      excludeSemantics: true,
      child: _buildVisual(config),
    );
  }

  Widget _buildVisual(_EstadoConfig config) {
    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: config.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            config.etiqueta,
            style: TextStyle(
              fontSize: 11,
              color: config.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: config.color.withValues(alpha: 0.4)),
      ),
      child: Text(
        config.etiqueta,
        style: TextStyle(
          color: config.color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _EstadoConfig {
  final Color color;
  final String etiqueta;
  const _EstadoConfig(this.color, this.etiqueta);
}

_EstadoConfig _configPorEstado(EstadoIncidente estado) {
  switch (estado) {
    case EstadoIncidente.CREADO:
      return _EstadoConfig(Colors.green.shade600, 'Creado');
    case EstadoIncidente.DERIVADO_A_CAI:
      return const _EstadoConfig(Colors.purple, 'Derivado a CAI');
    case EstadoIncidente.AGENTE_ASIGNADO:
      return const _EstadoConfig(Colors.teal, 'Agente asignado');
    case EstadoIncidente.AGENTE_EN_CAMINO:
      return const _EstadoConfig(Colors.blue, 'Agente en camino');
    case EstadoIncidente.EN_ATENCION:
      return const _EstadoConfig(Colors.indigo, 'En atención');
    case EstadoIncidente.FINALIZADO:
      return _EstadoConfig(Colors.green.shade800, 'Finalizado');
    case EstadoIncidente.CANCELADO:
      return const _EstadoConfig(Colors.red, 'Cancelado');
  }
}