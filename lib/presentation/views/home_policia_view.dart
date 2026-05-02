import 'package:CallSos/core/colores_app.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/policia_viewmodel.dart';
import 'package:CallSos/data/models/incident_cai_model.dart';

class HomePoliciaView extends StatelessWidget {
  const HomePoliciaView({super.key});

  @override
  Widget build(BuildContext context) {
    // Escuchamos al ViewModel
    final vm = Provider.of<PoliciaViewModel>(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.verdeClaro,
          title: Column(
            children: [
              Text(vm.cai.nombre, style: const TextStyle(fontSize: 18, color: Colors.black)), // DINÁMICO
              Text(vm.agente.nombre, style: const TextStyle(fontSize: 12, color: Colors.black)), // DINÁMICO
            ],
          ),
          //colocar pestaña para ver los agentes disponibles
          bottom: const TabBar(
            tabs: [Tab(text: "Pendientes"), Tab(text: "Historial")],
          ),
        ),
        body: TabBarView(
          children: [
            _ListaIncidentes(lista: vm.incidentesPendientes),
            _ListaIncidentes(lista: vm.incidentesCompletados),
          ],
        ),
      ),
    );
  }
}

class _ListaIncidentes extends StatelessWidget {
  final List<Incidente> lista;
  const _ListaIncidentes({required this.lista});

  @override
  Widget build(BuildContext context) {
    if (lista.isEmpty) return const Center(child: Text("No hay reportes para este CAI"));

    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: lista.length,
      itemBuilder: (context, index) {
        final incidente = lista[index];
        return Card(
          child: ListTile(
            leading: Icon(incidente.icono, color: incidente.color),
            title: Text(incidente.titulo),
            subtitle: Text(incidente.descripcion),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
          ),
        );
      },
    );
  }
}