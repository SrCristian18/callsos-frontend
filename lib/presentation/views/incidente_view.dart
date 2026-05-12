import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:CallSos/presentation/viewmodels/incidente_viewmodel.dart';
import 'package:CallSos/data/models/enums/rol.dart';
import '../widgets/comando_widget.dart';
import '../widgets/jefecai_widget.dart';
import '../widgets/agente_widget.dart';

class IncidenteView extends StatelessWidget {
  const IncidenteView({super.key});

  @override
  Widget build(BuildContext context) {
    // Escuchamos los cambios en el ViewModel
    final vm = context.watch<IncidenteViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestión de Incidentes"),
        backgroundColor: const Color(0xFF1B2A3B), // Azul institucional
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none))
        ],
      ),
      body: _buildByRole(vm),
    );
  }

  Widget _buildByRole(IncidenteViewModel vm) {
    switch (vm.currentUser.rol) {
      case Rol.COMANDO:
        return ComandoView(vm: vm);
      case Rol.JEFE_CAI:
        return JefeCaiView(vm: vm);
      case Rol.AGENTE_POLICIA:
        return AgenteView(vm: vm);
      default:
        return const Center(child: Text("Acceso no autorizado"));
    }
  }
}