import 'package:flutter/material.dart';

import '../../core/app_radius.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
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
///
/// EPIC-09 (Design System, auditoría UX/UI) — jerarquía visual: hasta
/// esta épica cada tamaño/radio/espaciado de esta card era un número
/// suelto elegido a mano (18, 14, 12, 11, 10...), sin relación con los
/// tokens que EPIC-01 ya había definido (`AppRadius`/`AppSpacing`/
/// `AppTextStyles`) — de hecho EPIC-01 documenta textualmente que
/// "ningún widget existente los usa todavía" y que migrar vista por
/// vista "es trabajo de las épicas de UI (EPIC-06 en adelante)". Esta
/// es esa migración para `IncidenteCard`. El cambio más deliberado es
/// el título: pasa de 15px/bold a `AppTextStyles.tituloMediano`
/// (18px/w600 — el token pensado exactamente para "títulos de card"),
/// para que se distinga más claramente de la descripción y los
/// metadatos — el hallazgo original de la auditoría era justamente
/// "mismo peso tipográfico en todo".
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
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.borderLg,
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
                Hero(
                  // EPIC-15 (microinteracciones) — mismo ícono/color que
                  // el de la card principal en `DetalleIncidenteView`;
                  // el tag por id de incidente conecta visualmente CUÁL
                  // card tocaste con el detalle que se abre (wayfinding:
                  // "esto es lo mismo que tenías en la mano", no un
                  // efecto porque sí). Tag único por incidente — varias
                  // `IncidenteCard` conviven en la misma lista.
                  tag: 'incidente-icono-${incidente.id}',
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: AppRadius.borderMd,
                    ),
                    child: Icon(icono, color: Colors.white, size: 26),
                  ),
                ),
                AppSpacing.gapMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: AppTextStyles.tituloMediano,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        incidente.descripcion.isNotEmpty
                            ? incidente.descripcion
                            : (presentacion?.descripcion ?? ''),
                        style: AppTextStyles.cuerpoPequeno
                            .copyWith(color: Colors.grey.shade600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                AppSpacing.gapSm,
                EstadoChip(estado: incidente.estado),
              ],
            ),
            AppSpacing.gapMd,
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  _formatearFecha(incidente.fechaHora),
                  style: AppTextStyles.etiqueta.copyWith(color: Colors.grey.shade600),
                ),
                if (incidente.nombreCAI != null) ...[
                  AppSpacing.gapMd,
                  Icon(Icons.domain_outlined, size: 13, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      incidente.nombreCAI!,
                      style: AppTextStyles.etiqueta.copyWith(color: Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            if (labelAccion != null) ...[
              AppSpacing.gapMd,
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onAccion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.negroTexto,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
                  ),
                  child: Text(
                    labelAccion!,
                    style: AppTextStyles.cuerpoPequeno
                        .copyWith(fontWeight: FontWeight.w600, color: Colors.white),
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