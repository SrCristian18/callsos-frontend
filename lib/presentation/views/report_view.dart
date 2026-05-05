import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:CallSos/core/colores_app.dart';
import 'package:CallSos/presentation/viewmodels/incident_viewmodel.dart';
import 'package:CallSos/data/models/incident.dart';
import 'package:CallSos/data/models/incident_type.dart'; // Importa el nuevo modelo

class ReportView extends StatelessWidget {
  const ReportView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<IncidentViewModel>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.blancoVerde,
        appBar: AppBar(
          backgroundColor: const Color(0xFF1B2A3B),
          elevation: 0,
          title: const Text("CallSOS - Auxilio", style: TextStyle(color: Colors.white)),
          bottom: const TabBar(
            indicatorColor: Colors.greenAccent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.add_alert), text: "Reportar"),
              Tab(icon: Icon(Icons.history), text: "Mis Reportes"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildReportarSection(context, vm),
            _buildHistorialSection(vm),
          ],
        ),
      ),
    );
  }

  // SECCIÓN 1: GRILLA DE REPORTES (Corregida con IncidentType)
  Widget _buildReportarSection(BuildContext context, IncidentViewModel vm) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 1,
      ),
      itemCount: vm.catalogTypes.length, // Usamos la lista de objetos
      itemBuilder: (context, index) {
        final IncidentType type = vm.catalogTypes[index]; // Objeto tipado
        return InkWell(
          onTap: () => _confirmarEnvio(context, type),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(type.icon, size: 50, color: type.color), // Acceso por propiedad .
                const SizedBox(height: 10),
                Text(type.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      },
    );
  }

  // SECCIÓN 2: HISTORIAL (Asegúrate que vm.misReportes devuelva List<Incident>)
  Widget _buildHistorialSection(IncidentViewModel vm) {
    final reportes = vm.allIncidents;

    if (reportes.isEmpty) {
      return const Center(child: Text("Aún no has realizado reportes."));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: reportes.length,
      itemBuilder: (context, index) {
        final item = reportes[index];
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: ListTile(
            leading: _buildStatusIcon(item.status),
            title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Estado: ${_formatStatus(item.status)}"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
          ),
        );
      },
    );
  }

  Widget _buildStatusIcon(IncidentStatus status) {
    Color color;
    switch (status) {
      case IncidentStatus.RECIBIDO: color = Colors.orange; break;
      case IncidentStatus.CAI_ASIGNADO: color = Colors.blue; break;
      case IncidentStatus.COMPLETADO: color = Colors.green; break;
      default: color = Colors.grey;
    }
    return CircleAvatar(
      backgroundColor: color.withOpacity(0.2), 
      child: Icon(Icons.info, color: color, size: 20)
    );
  }

  String _formatStatus(IncidentStatus status) {
    return status.toString().split('.').last.replaceAll('_', ' ');
  }

  void _confirmarEnvio(BuildContext context, IncidentType type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("¿Reportar ${type.title}?"),
        content: const Text("Se enviará tu ubicación actual al comando de policía para asignar el CAI más cercano."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B2A3B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
            ),
            onPressed: () {
              // Aquí disparas la lógica real del VM más adelante
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Reporte de ${type.title} enviado"),
                  backgroundColor: AppColors.verdeOscuro,
                )
              );
            },
            child: const Text("Enviar Reporte", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}