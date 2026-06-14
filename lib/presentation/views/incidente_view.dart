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
      // F.0.2: Rol.JEFE_CAI -> Rol.OPERADOR_CAI (alineación con backend).
      case Rol.OPERADOR_CAI:
        return JefeCaiView(vm: vm);
      // F.0.2: Rol.AGENTE_POLICIA -> Rol.AGENTE (alineación con backend).
      case Rol.AGENTE:
        return AgenteView(vm: vm);
      // Rol.DENUNCIANTE (nuevo en F.0.2) y cualquier otro caso: esta vista
      // es exclusiva de roles policiales, el denunciante usa otro flujo
      // (HomeDenuncianteView, F.2).
      default:
        return const Center(child: Text("Acceso no autorizado"));
    }
  }
}