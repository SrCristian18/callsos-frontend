import 'package:CallSos/data/models/enums/estado_incidente.dart';
import 'package:CallSos/data/models/incidente_reportado.dart';
import 'package:CallSos/presentation/viewmodels/incidente_viewmodel.dart';
import 'package:flutter/material.dart';

class ComandoView extends StatelessWidget {
  final IncidenteViewModel vm;
  const ComandoView({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: Color(0xFF1B2A3B),
            indicatorColor: Colors.green,
            tabs: [Tab(text: "Reportados"), Tab(text: "Delegados")],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _listaIncidentesNuevos(),
                _listaIncidentesDelegados(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _listaIncidentesNuevos() {
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: vm.nuevosIncidentes.length,
      itemBuilder: (context, index) {
        final item = vm.nuevosIncidentes[index];
        return Card(
          child: ListTile(
            title: Text(item.incidente.titulo),
            subtitle: const Text("Seleccionar CAI cercano..."),
            trailing: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () => _mostrarAsignacionCAI(context, item),
              child: const Text("Delegar"),
            ),
          ),
        );
      },
    );
  }
  
  Widget _listaIncidentesDelegados() {
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: vm.incidentosDelegados.length,
      itemBuilder: (context, index) {
        final item = vm.incidentosDelegados[index];
        return Card(
          child: ListTile(
            title: Text(item.incidente.titulo),
            subtitle: Text("Delegado a: ${item.caiId}"),
            trailing: Icon(
              // F.0.2: 'COMPLETADO' -> EstadoIncidente.FINALIZADO
              // (comparación por enum en vez de string, para que el
              // analizador detecte futuros desalineamientos).
              item.estado == EstadoIncidente.FINALIZADO
                  ? Icons.check_circle
                  : Icons.pending,
              color: item.estado == EstadoIncidente.FINALIZADO
                  ? Colors.green
                  : Colors.orange,
            ),
          ),
        );
      },
    );
  }
  
  void _mostrarAsignacionCAI(BuildContext context, IncidenteReportado item) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final cais = ["CAI San Francisco", "CAI Chapinero", "CAI Suba"];
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Delegar Incidente a CAI", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ...cais.map((cai) => ListTile(
                title: Text(cai),
                leading: const Icon(Icons.location_on, color: Colors.green),
                onTap: () {
                  vm.delegarACai(item.id, cai);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Incidente delegado a $cai"))
                  );
                },
              )),
            ],
          ),
        );
      },
    );
  }
  
  // ... resto de lógica de delegados
}