import 'package:flutter/material.dart';

import '../../core/colores_app.dart';
import '../../data/models/incidente.dart';
import '../viewmodels/incidente_list_viewmodel.dart';
import 'empty_state.dart';
import 'error_view.dart';
import 'incidente_card.dart';
import 'incidente_card_skeleton.dart';

/// Widget que renderiza el cuerpo de una lista de incidentes según el estado
/// del [IncidenteListViewModel].
///
/// F.2 — Compartido entre todas las Home views por rol.
///
/// Maneja:
/// - Loading inicial: [IncidenteListSkeleton] (EPIC-15).
/// - Error (sin datos previos): [ErrorView] con botón "Reintentar".
/// - Lista vacía: [EmptyState].
/// - Lista con datos: [RefreshIndicator] + [ListView] de [IncidenteCard].
///
/// EPIC-09 (Design System, auditoría UX/UI) — checklist §18
/// (loading/success/error/empty): antes cada uno de estos 3 estados
/// tenía acá su propio bloque `Center(Padding(Column(Icon+Text+...)))`
/// escrito a mano, prácticamente idéntico (mismo ícono, mismos tonos de
/// gris, mismo botón "Reintentar") al que EPIC-03 ya había extraído a
/// [LoadingView]/[ErrorView]/[EmptyState] — pero sin conectarlos acá
/// todavía (ver el comentario de cada uno: "hoy se repite... en
/// incidente_list_body.dart"). Ese fix fue exactamente esa conexión:
/// ningún comportamiento nuevo, mismo resultado visual, una sola fuente
/// de verdad para los 3 estados en toda la app.
///
/// EPIC-15 (Microinteracciones) — el estado de loading inicial pasó de
/// [LoadingView] (spinner centrado) a [IncidenteListSkeleton]: acá SÍ
/// vale la pena anticipar la forma del contenido (varias cards, todas
/// iguales) — ver el comentario de clase de
/// [IncidenteCardSkeleton] para por qué NO se aplicó el mismo criterio
/// en otras pantallas de loading de la app (ej. `DetalleIncidenteView`,
/// que sigue usando [LoadingView] sin cambios).
///
/// [buildCard] permite que cada Home personalice la card (con distintas
/// acciones y etiquetas de botón según el rol).
class IncidenteListBody extends StatelessWidget {
  final IncidenteListViewModel vm;
  final List<Incidente> incidentes;
  final String mensajeVacio;
  final IconData iconoVacio;

  /// Construye la card para cada incidente. Recibe el incidente y devuelve
  /// el widget (normalmente un [IncidenteCard] con [onTap]/[onAccion]
  /// apropiados para el rol).
  final Widget Function(Incidente) buildCard;

  const IncidenteListBody({
    super.key,
    required this.vm,
    required this.incidentes,
    required this.buildCard,
    this.mensajeVacio = 'No hay incidentes disponibles.',
    this.iconoVacio = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    // Loading inicial — `vm.isLoading` es EXCLUSIVO de `cargar()`;
    // `refrescar()` (pull-to-refresh) usa `vm.isRefreshing`, una bandera
    // separada que este widget ni siquiera lee, así que el skeleton de
    // acá abajo nunca tapa una lista que ya tenía datos — el
    // `RefreshIndicator` de más abajo ya se encarga de ese caso con su
    // propio spinner nativo.
    if (vm.isLoading) {
      return const IncidenteListSkeleton();
    }

    // Error (sin datos previos que mostrar)
    if (vm.errorMessage != null && incidentes.isEmpty) {
      return ErrorView(message: vm.errorMessage!, onRetry: vm.cargar);
    }

    // Lista vacía
    if (incidentes.isEmpty) {
      return EmptyState(icon: iconoVacio, message: mensajeVacio);
    }

    // Error inline (hay datos pero la última operación falló) — no es
    // uno de los 4 estados del checklist (ese ya está cubierto arriba,
    // para cuando NO hay datos); acá sigue siendo un banner propio
    // porque conceptualmente es distinto: "success con una advertencia
    // encima", no un ErrorView de página completa que reemplazaría la
    // lista que el usuario sigue pudiendo ver y usar.
    return Column(
      children: [
        if (vm.errorMessage != null)
          Container(
            width: double.infinity,
            color: Colors.red.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 16, color: Colors.red.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    vm.errorMessage!,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.verdeOscuro,
            onRefresh: vm.refrescar,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: incidentes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => buildCard(incidentes[i]),
            ),
          ),
        ),
      ],
    );
  }
}