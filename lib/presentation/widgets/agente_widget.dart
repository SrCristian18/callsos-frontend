import 'package:CallSos/presentation/viewmodels/incidente_viewmodel.dart';
import 'package:flutter/material.dart';

class AgenteView extends StatelessWidget {
  final IncidenteViewModel vm;
  const AgenteView({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildInfoPerfil(vm.currentUser.name, vm.currentUser.caiName),
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text("MIS ASIGNACIONES", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: vm.misAsignaciones.isEmpty 
            ? const Center(child: Text("No tienes incidentes asignados"))
            : ListView.builder(
                itemCount: vm.misAsignaciones.length,
                itemBuilder: (context, index) {
                  final item = vm.misAsignaciones[index];
                  return Card(
                    child: ListTile(
                      leading: Icon(item.incidente.icono, color: item.incidente.color),
                      title: Text(item.incidente.titulo),
                      subtitle: Text(item.ubicacion),
                      trailing: IconButton(
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        onPressed: () => _completarTarea(context, item.id),
                      ),
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }
  
  Widget _buildInfoPerfil(String name, String caiName) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.grey[200]),
      child: Row(
        children: [
          const CircleAvatar(child: Icon(Icons.person)),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text("CAI: $caiName", style: const TextStyle(color: Colors.grey)),
            ],
          )
        ],
      ),
    );
  }
  
  void _completarTarea(BuildContext context, String incidentId) {
    vm.completarIncidente(incidentId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Incidente marcado como completado"))
    );
  }
}