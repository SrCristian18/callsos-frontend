import 'package:CallSos/core/colores_app.dart';
import 'package:CallSos/data/models/enums/estado_incidente.dart';
import 'package:CallSos/presentation/viewmodels/reporte_viewmodel.dart';
import 'package:flutter/material.dart';

class ReporteView extends StatefulWidget {
  const ReporteView({super.key});

  @override
  State<ReporteView> createState() => _ReporteView();
}

class _ReporteView extends State<ReporteView> {
  final vm = ReporteViewModel();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blancoVerde,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: vm,
          builder: (_, __) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                children: [
                  const SizedBox(height: 12),

                  /// HEADER
                  _buildHeader(),

                  const SizedBox(height: 14),

                  /// TABS
                  _buildTabs(),

                  const SizedBox(height: 14),

                  /// CONTENIDO
                  Expanded(
                    child: vm.currentIndex == 0
                        ? _buildIncidentes()
                        : _buildReportados(),
                  ),

                  const SizedBox(height: 12),

                  /// FOOTER
                  _buildBottomButtons(),

                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// =====================================================
  /// HEADER
  /// =====================================================

  Widget _buildHeader() {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.negroTexto,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 15,
            backgroundColor: Colors.white24,
            child: Icon(
              Icons.person,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),

          const Expanded(
            child: Text(
              "Usuario",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          Icon(
            Icons.notifications_none_rounded,
            color: Colors.white.withOpacity(0.8),
          ),
        ],
      ),
    );
  }

  /// =====================================================
  /// TABS
  /// =====================================================

  Widget _buildTabs() {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _tabItem(
              title: "Denuncias",
              selected: vm.currentIndex == 0,
              onTap: () => vm.changeTab(0),
            ),
          ),
          Expanded(
            child: _tabItem(
              title: "Estado",
              selected: vm.currentIndex == 1,
              onTap: () => vm.changeTab(1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabItem({
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? AppColors.negroTexto
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : AppColors.negroTexto,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  /// =====================================================
  /// LISTA INCIDENTES
  /// =====================================================

  Widget _buildIncidentes() {
    return ListView.separated(
      itemCount: vm.incidentes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, index) {
        final incidente = vm.incidentes[index];

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              /// ICONO
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: incidente.color,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  incidente.icono,
                  color: Colors.white,
                  size: 28,
                ),
              ),

              const SizedBox(width: 12),

              /// TEXTO
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incidente.titulo,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.negroTexto,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      incidente.descripcion,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              /// BOTON +
              GestureDetector(
                onTap: () {
                  vm.agregarReporte(incidente);
                },
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.verdeClaro,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// =====================================================
  /// REPORTADOS
  /// =====================================================

  Widget _buildReportados() {
    if (vm.reportados.isEmpty) {
      return const Center(
        child: Text(
          "No hay denuncias registradas",
        ),
      );
    }

    return ListView.separated(
      itemCount: vm.reportados.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, index) {
        final reporte = vm.reportados[index];

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              /// ICONO
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: reporte.incidente.color,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  reporte.incidente.icono,
                  color: Colors.white,
                  size: 28,
                ),
              ),

              const SizedBox(width: 12),

              /// INFO
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reporte.incidente.titulo,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.negroTexto,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      reporte.incidente.descripcion,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Icon(
                          Icons.calendar_month,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),

                        const SizedBox(width: 4),

                        Text(
                          "${reporte.fechaCreacion.day}/${reporte.fechaCreacion.month}/${reporte.fechaCreacion.year}",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),

                        const SizedBox(width: 10),

                        _estadoChip(reporte.estado),
                      ],
                    ),
                  ],
                ),
              ),

              /// BOTON X
              GestureDetector(
                onTap: () {
                  vm.eliminarReporte(reporte.id);
                },
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// =====================================================
  /// ESTADO CHIP
  /// =====================================================

  Widget _estadoChip(EstadoIncidente estado) {
    Color color;
    String texto;

    // F.0.2: switch reescrito sobre el EstadoIncidente alineado al backend
    // (CREADO, DERIVADO_A_CAI, AGENTE_ASIGNADO, AGENTE_EN_CAMINO,
    // EN_ATENCION, FINALIZADO, CANCELADO). Los antiguos PENDIENTE/INCOMPLETO
    // no existen en el backend y se eliminaron; este helper será
    // reemplazado por el widget reutilizable `estado_chip.dart` en F.1.
    switch (estado) {
      case EstadoIncidente.CREADO:
        color = Colors.green;
        texto = "Creado";
        break;

      case EstadoIncidente.DERIVADO_A_CAI:
        color = Colors.purple;
        texto = "Derivado a CAI";
        break;

      case EstadoIncidente.AGENTE_ASIGNADO:
        color = Colors.lightGreen;
        texto = "Agente asignado";
        break;

      case EstadoIncidente.AGENTE_EN_CAMINO:
        color = Colors.blue;
        texto = "Agente en camino";
        break;

      case EstadoIncidente.EN_ATENCION:
        color = Colors.indigo;
        texto = "En atención";
        break;

      case EstadoIncidente.FINALIZADO:
        color = Colors.lightGreenAccent;
        texto = "Finalizado";
        break;

      case EstadoIncidente.CANCELADO:
        color = Colors.red;
        texto = "Cancelado";
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// =====================================================
  /// BOTTOM BUTTONS
  /// =====================================================

  Widget _buildBottomButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              side: const BorderSide(
                color: AppColors.verdeOscuro,
              ),
              foregroundColor: AppColors.negroTexto,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text("Cancelar"),
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.negroTexto,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text("Agregar"),
          ),
        ),
      ],
    );
  }
}