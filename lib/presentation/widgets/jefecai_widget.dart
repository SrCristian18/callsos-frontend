import 'package:flutter/material.dart';
import '../viewmodels/incident_viewmodel.dart';
import '../../data/models/incident.dart';

class JefeCaiView extends StatelessWidget {
  final IncidentViewModel vm;
  const JefeCaiView({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    final reportes = vm.filteredIncidents;

    if (reportes.isEmpty) {
      return const Center(child: Text("No hay incidentes pendientes por asignar."));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: reportes.length,
      itemBuilder: (context, index) {
        final incidente = reportes[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(incidente.title, 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const Icon(Icons.assignment_ind, color: Color(0xFF1B2A3B)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(incidente.description, style: TextStyle(color: Colors.grey[600])),
                const Divider(height: 30),
                const Text("Asignar a agente disponible:", 
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                // Simulamos una lista de agentes del CAI
                Row(
                  children: [
                    Expanded(
                      child: ActionChip(
                        avatar: const CircleAvatar(child: Text("M")),
                        label: const Text("Agente Murillo"),
                        onPressed: () => _mostrarConfirmacion(context, incidente, "Agente Murillo"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ActionChip(
                        avatar: const CircleAvatar(child: Text("G")),
                        label: const Text("Agente Gomez"),
                        onPressed: () => _mostrarConfirmacion(context, incidente, "Agente Gomez"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _mostrarConfirmacion(BuildContext context, Incident incident, String agente) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmar Asignación"),
        content: Text("¿Desea asignar el caso '${incident.title}' al $agente?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B2A3B)),
            onPressed: () {
              // Aquí llamarías a vm.assignToAgent(incident.id, agenteId);
              Navigator.pop(context);
            },
            child: const Text("Asignar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}