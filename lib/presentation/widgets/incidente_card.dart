import 'package:flutter/material.dart';

import '../../core/colores_app.dart';
import '../../data/models/incidente.dart';
import '../../data/models/tipo_incidente_presentacion.dart';
import 'estado_chip.dart';

/// Card reutilizable para mostrar un [Incidente] en cualquier lista.
///
/// F.1 — Widgets base.
///
/// Combina:
/// - Icono/color de [TipoIncidentePresentacion].
/// - [EstadoChip] (F.1).
/// - Fecha, descripción y CAI asignado (si existe).
/// - Callback [onTap] para navegar a [DetalleIncidenteView] (F.2).
/// - Callback [onAccion] opcional para acciones contextuales por rol.
class IncidenteCard extends StatelessWidget {
  final Incidente incidente;
  final VoidCallback? onTap;
  final String? labelAccion;
  final VoidCallback? onAccion;

  const IncidenteCard({
    super.key,
    required this.incidente,
    this.onTap,
    this.labelAccion,
    this.onAccion,
  }) : assert(
          labelAccion == null || onAccion != null,
          'Si se provee labelAccion, onAccion no puede ser null.',
        );

  @override
  Widget build(BuildContext context) {
    final presentacion = catalogoTipos[incidente.tipo];
    final color = presentacion?.color ?? Colors.grey;
    final icono = presentacion?.icono ?? Icons.warning_amber_rounded;
    final titulo = presentacion?.titulo ?? incidente.tipo.name;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icono, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.negroTexto,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        incidente.descripcion.isNotEmpty
                            ? incidente.descripcion
                            : (presentacion?.descripcion ?? ''),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                EstadoChip(estado: incidente.estado),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  _formatearFecha(incidente.fechaHora),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                if (incidente.nombreCAI != null) ...[
                  const SizedBox(width: 10),
                  Icon(Icons.domain_outlined, size: 13, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      incidente.nombreCAI!,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            if (labelAccion != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onAccion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.negroTexto,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    labelAccion!,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatearFecha(DateTime fecha) {
    final d = fecha.day.toString().padLeft(2, '0');
    final m = fecha.month.toString().padLeft(2, '0');
    final h = fecha.hour.toString().padLeft(2, '0');
    final min = fecha.minute.toString().padLeft(2, '0');
    return '$d/$m/${fecha.year}  $h:$min';
  }
}