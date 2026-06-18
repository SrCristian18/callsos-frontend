import 'package:flutter/material.dart';

import '../../core/colores_app.dart';
import '../../data/models/incidente.dart';
import '../viewmodels/incidente_list_viewmodel.dart';
import 'incidente_card.dart';

/// Widget que renderiza el cuerpo de una lista de incidentes según el estado
/// del [IncidenteListViewModel].
///
/// F.2 — Compartido entre todas las Home views por rol.
///
/// Maneja:
/// - Loading inicial: skeleton/spinner centrado.
/// - Error: mensaje + botón "Reintentar".
/// - Lista vacía: ícono + mensaje contextual.
/// - Lista con datos: [RefreshIndicator] + [ListView] de [IncidenteCard].
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
    // Loading inicial
    if (vm.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.verdeOscuro),
      );
    }

    // Error
    if (vm.errorMessage != null && incidentes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_outlined, size: 52, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                vm.errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.verdeOscuro,
                  foregroundColor: Colors.white,
                ),
                onPressed: vm.cargar,
              ),
            ],
          ),
        ),
      );
    }

    // Lista vacía
    if (incidentes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(iconoVacio, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              mensajeVacio,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
            ),
          ],
        ),
      );
    }

    // Error inline (hay datos pero la última operación falló)
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
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => buildCard(incidentes[i]),
            ),
          ),
        ),
      ],
    );
  }
}