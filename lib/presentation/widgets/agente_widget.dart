import 'package:flutter/material.dart';
import '../viewmodels/incident_viewmodel.dart';

class AgenteView extends StatelessWidget {
  final IncidentViewModel vm;
  const AgenteView({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    final misCasos = vm.filteredIncidents;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          width: double.infinity,
          color: const Color(0xFFF0F4F0),
          child: const Text(
            "MIS CASOS ASIGNADOS",
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B2A3B)),
          ),
        ),
        Expanded(
          child: misCasos.isEmpty
              ? const Center(child: Text("No tienes casos asignados actualmente."))
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: misCasos.length,
                  itemBuilder: (context, index) {
                    final incidente = misCasos[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFF1B2A3B),
                            child: Icon(Icons.warning_amber_rounded, color: Colors.white),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(incidente.title, 
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text(incidente.description, 
                                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4CAF50), // Verde de tus botones
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              // vm.completeIncident(incidente.id);
                            },
                            child: const Text("Finalizar", 
                              style: TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}