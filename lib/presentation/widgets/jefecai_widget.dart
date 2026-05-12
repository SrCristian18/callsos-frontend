import 'package:CallSos/data/models/incidente_reportado.dart';
import 'package:CallSos/presentation/viewmodels/incidente_viewmodel.dart';
import 'package:flutter/material.dart';

class JefeCaiView extends StatelessWidget {
  final IncidenteViewModel vm;
  const JefeCaiView({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          _buildHeader(vm.currentUser.caiName),
          const TabBar(
            tabs: [Tab(text: "Por Asignar"), Tab(text: "Historial")],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildPendientesAsignacion(),
                _buildHistorialAsignados(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendientesAsignacion() {
    return ListView.builder(
      itemCount: vm.pendientesPorAsignar.length,
      itemBuilder: (context, index) {
        final item = vm.pendientesPorAsignar[index];
        return Card(
          margin: const EdgeInsets.all(8),
          child: Column(
            children: [
              ListTile(
                title: Text(item.incidente.titulo),
                subtitle: Text("Ubicación: ${item.ubicacion}"),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () {}, child: const Text("Ver detalles")),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _mostrarAsignacionAgente(context, item), 
                    child: const Text("Asignar Agente")
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildHeader(String nombreCai) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.green.shade50,
      width: double.infinity,
      child: Text(
        "Gestionando: $nombreCai",
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
      ),
    );
  }
  
  Widget _buildHistorialAsignados() {
    return ListView.builder(
      itemCount: vm.historialCai.length,
      itemBuilder: (context, index) {
        final item = vm.historialCai[index];
        return ListTile(
          leading: const Icon(Icons.history),
          title: Text(item.incidente.titulo),
          subtitle: Text("Agente: ${item.agenteId} - Estado: ${item.estado.name}"),
        );
      },
    );
  }

  void _mostrarAsignacionAgente(BuildContext context, IncidenteReportado item) {
    showDialog(
      context: context,
      builder: (context) {
        final agentes = ["Agente Juan Perez", "Agente Maria Lopez", "Agente Carlos Ruiz"];
        return AlertDialog(
          title: const Text("Seleccionar Agente"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: agentes.map((agente) => ListTile(
                title: Text(agente),
                onTap: () {
                  vm.asignarAgente(item.id, agente);
                  Navigator.pop(context);
                },
              )).toList(),
            ),
          ),
        );
      },
    );
  }
}