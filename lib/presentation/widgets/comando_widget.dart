import 'package:CallSos/presentation/viewmodels/incident_viewmodel.dart';
import 'package:flutter/material.dart';

class ComandoView extends StatelessWidget {
  final IncidentViewModel vm;
  const ComandoView({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: vm.filteredIncidents.length,
      itemBuilder: (context,index) {
        final incident = vm.filteredIncidents[index];
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: ListTile(
            title: Text(incident.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text("Sugerencia: CAI San Francisco (a 200m)"),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50)),
              onPressed: () => vm.assignToCai(incident.id, "CAI_SF", "SF"),
              child: const Text("Autorizar", style: TextStyle(color: Colors.white)),
            ),
          ),
        );
      },
    );
  }
}