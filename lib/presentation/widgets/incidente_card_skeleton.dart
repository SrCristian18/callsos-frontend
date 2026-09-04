import 'package:flutter/material.dart';

import '../../core/app_radius.dart';
import '../../core/app_spacing.dart';

/// Placeholder tipo "esqueleto" con la misma silueta que [IncidenteCard]
/// (caja de ícono 52×52, título, descripción de 2 líneas, chip de
/// estado, línea de metadatos) mientras la lista todavía está
/// cargando.
///
/// EPIC-15 (Microinteracciones) — "skeleton loading donde aporte
/// (listas de incidentes)": antes, el loading inicial de
/// `IncidenteListBody` era un spinner centrado y solo — la pantalla se
/// veía completamente vacía hasta que llegaban los datos. Un esqueleto
/// que anticipa la FORMA del contenido (cuántas cards, dónde va cada
/// pieza) reduce la percepción de espera y evita el "salto" brusco de
/// spinner-vacío a lista-llena. Se usa acá específicamente — y no en,
/// por ejemplo, `DetalleIncidenteView` — porque ahí el contenido es
/// una sola card con forma poco predecible de antemano (descripción de
/// largo variable, CAI opcional); en una LISTA, en cambio, la forma se
/// repite N veces y sí vale la pena anticiparla.
///
/// La animación es un barrido de brillo (shimmer) hecho a mano con
/// `AnimationController` + `ShaderMask` — se evitó sumar una dependencia
/// nueva (paquete `shimmer`) solo para este efecto.
class IncidenteCardSkeleton extends StatefulWidget {
  const IncidenteCardSkeleton({super.key});

  @override
  State<IncidenteCardSkeleton> createState() => _IncidenteCardSkeletonState();
}

class _IncidenteCardSkeletonState extends State<IncidenteCardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            // Barrido de izquierda a derecha: el gradiente se desplaza
            // con `_controller.value` (0→1) por fuera de los límites del
            // widget en ambos extremos, para que el brillo entre y
            // salga completo (no aparezca "cortado" a mitad de pantalla).
            final desplazamiento = _controller.value * 2 - 1; // -1 → 1
            return LinearGradient(
              colors: [
                Colors.grey.shade300,
                Colors.grey.shade100,
                Colors.grey.shade300,
              ],
              stops: const [0.35, 0.5, 0.65],
              begin: Alignment(-1 - desplazamiento, 0),
              end: Alignment(1 - desplazamiento, 0),
            ).createShader(bounds);
          },
          child: _siluetaCard(),
        );
      },
    );
  }

  Widget _siluetaCard() {
    Widget barra({required double ancho, double alto = 12}) => Container(
          width: ancho,
          height: alto,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(4),
          ),
        );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.borderLg,
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
                  color: Colors.grey.shade300,
                  borderRadius: AppRadius.borderMd,
                ),
              ),
              AppSpacing.gapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    barra(ancho: 140, alto: 16),
                    const SizedBox(height: 8),
                    barra(ancho: double.infinity, alto: 12),
                    const SizedBox(height: 6),
                    barra(ancho: 180, alto: 12),
                  ],
                ),
              ),
              AppSpacing.gapSm,
              Container(
                width: 64,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ],
          ),
          AppSpacing.gapMd,
          barra(ancho: 120, alto: 11),
        ],
      ),
    );
  }
}

/// Lista de [IncidenteCardSkeleton] separadas — mismo padding/separación
/// que la `ListView.separated` real de `IncidenteListBody`, para que el
/// paso de skeleton → contenido real no "salte" de posición.
class IncidenteListSkeleton extends StatelessWidget {
  final int cantidad;

  const IncidenteListSkeleton({super.key, this.cantidad = 4});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cantidad,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => const IncidenteCardSkeleton(),
    );
  }
}