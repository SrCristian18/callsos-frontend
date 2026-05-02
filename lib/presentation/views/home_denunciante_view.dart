import 'package:CallSos/core/colores_app.dart';
import 'package:flutter/material.dart';
import '../../data/models/incident_model.dart';

class HomeDenuncianteView extends StatelessWidget {
  HomeDenuncianteView({super.key});

  // ESTO ES EL "DOMINIO": Luego vendrá de un Service o ViewModel
  final List<IncidentType> incidentTypes = [
    IncidentType(title: "Ruido excesivo", subtitle: "Problemas de contaminación sonora", icon: Icons.volume_up, color: Colors.purple),
    IncidentType(title: "Abuso infantil", subtitle: "Violencia o maltrato contra menores", icon: Icons.child_care, color: Colors.orange),
    IncidentType(title: "Incidente de tránsito", subtitle: "Accidente o siniestro vial", icon: Icons.directions_car, color: Colors.blue),
    IncidentType(title: "Riñas o peleas", subtitle: "Conflicto físico entre personas", icon: Icons.fitness_center, color: Colors.green),
    IncidentType(title: "Violencia doméstica", subtitle: "Agresión en el ámbito familiar", icon: Icons.back_hand, color: Colors.deepPurple),
    IncidentType(title: "Robos o asaltos", subtitle: "Delito de hurto o atraco", icon: Icons.monetization_on, color: Colors.red),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.blancoVerde, // Blanco verdoso muy claro
        appBar: AppBar(
          backgroundColor:AppColors.verdeClaro, // Tu azul oscuro de los mockups
          elevation: 0,
          title: Row(
            children: [
              const CircleAvatar(
                backgroundImage: NetworkImage('https://via.placeholder.com/150'), // Foto de Dinakaran
              ),
              const SizedBox(width: 12),
              const Text("Usuario", style: TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          actions: [
            IconButton(icon: const Icon(Icons.notifications_none, color: Colors.white), onPressed: () {}),
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: "Incidentes"),
              Tab(text: "Reportes realizados"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildDenunciasTab(),
            _buildEstadoTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildDenunciasTab() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: incidentTypes.length,
            itemBuilder: (context, index) {
              final type = incidentTypes[index];
              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: type.color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Icon(type.icon, color: type.color),
                  ),
                  title: Text(type.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(type.subtitle, style: const TextStyle(fontSize: 12)),
                  trailing: Icon(Icons.add_box, color: AppColors.verdeOscuro),
                  onTap: () { /* Abrir formulario de reporte */ },
                ),
              );
            },
          ),
        ),
        _buildBottomButtons(),
      ],
    );
  }

  Widget _buildEstadoTab() {
    return const Center(
      child: Text("Aquí se verán tus reportes en proceso..."),
    );
  }

  //Se puede considerar borrar estos botones, y colocar el "viene" como
  //una opción de revisar estado dentro del incidente reportado (la pestaña de derecha)
  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF1B2A3B)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {},
              child: const Text("Cancelar", style: TextStyle(color: Color(0xFF1B2A3B))),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B2A3B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {},
              child: const Text("¿Viene?", style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
  //Hasta aquí se borra

}