import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:CallSos/presentation/viewmodels/incident_viewmodel.dart';
import 'package:CallSos/data/models/role.dart';
import 'package:CallSos/core/colores_app.dart';
import 'package:CallSos/presentation/widgets/agente_widget.dart';
import 'package:CallSos/presentation/widgets/comando_widget.dart';
import 'package:CallSos/presentation/widgets/jefecai_widget.dart';

class IncidentView extends StatelessWidget {
  const IncidentView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<IncidentViewModel>();

    return Scaffold(
      backgroundColor: AppColors.blancoVerde,
      appBar: AppBar(
        title: const Text("Incidentes", style: TextStyle(color: Colors.white),),
        backgroundColor: AppColors.verdeOscuro,
      ),
      body: _buildByRole(vm),
    );
  }

  Widget _buildByRole(IncidentViewModel vm) {
    switch (vm.currentUserRole) {
      case Role.COMANDO:
        return ComandoView(vm: vm);
      case Role.JEFECAI:
        return JefeCaiView(vm: vm);
      case Role.AGENTE_POLICIA:
        return AgenteView(vm: vm);
      default:
        return const Center(child: Text("Sin acceso"));
    }
  }
}