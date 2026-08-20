import 'package:flutter/material.dart';

import '../../core/colores_app.dart';
import '../../data/models/enums/tipo_incidente_enum.dart';
import '../../data/models/tipo_incidente_presentacion.dart';

/// Épica 6 — selector de tipo de incidente, usado desde
/// `DetalleIncidenteView` para que el denunciante dueño actualice el tipo
/// de su incidente activo (`PATCH /incidentes/{id}/tipo`).
///
/// Reutiliza [catalogoTipos] (F.0.2) en vez de duplicar títulos/íconos/
/// colores — mismo catálogo que ya usa la card principal del detalle y
/// `ReporteView`.
///
/// El tipo ACTUAL del incidente se excluye de las opciones: no tiene
/// sentido ofrecer "cambiar a lo mismo", y el backend lo rechaza de
/// todas formas con 422 (`ActualizarTipoIncidenteService` — "mismo tipo
/// → rechazo").
///
/// Devuelve el [TipoIncidenteEnum] elegido, o `null` si el usuario cierra
/// el selector sin elegir (deslizando hacia abajo o tocando fuera). Elegir
/// una opción de la lista ES el gesto de confirmación — no hay un segundo
/// diálogo de "¿estás seguro?", mismo patrón que el resto de acciones de
/// una sola llamada de esta vista (ej. "Cancelar emergencia").
Future<TipoIncidenteEnum?> mostrarSelectorTipoIncidente(
  BuildContext context, {
  required TipoIncidenteEnum tipoActual,
}) {
  final opciones = catalogoTipos.entries
      .where((entry) => entry.key != tipoActual)
      .toList();

  return showModalBottomSheet<TipoIncidenteEnum>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text(
                'Actualizar tipo de incidente',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.negroTexto,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Elige el tipo que mejor describe la situación ahora.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: opciones.map((entry) {
                  final tipo = entry.key;
                  final pres = entry.value;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: pres.color,
                      child: Icon(pres.icono, color: Colors.white, size: 20),
                    ),
                    title: Text(
                      pres.titulo,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      pres.descripcion,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () => Navigator.pop(ctx, tipo),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}