import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:CallSos/presentation/viewmodels/login_viewmodel.dart';
import 'package:CallSos/presentation/viewmodels/reporte_viewmodel.dart';
import 'package:CallSos/presentation/viewmodels/incidente_viewmodel.dart';
import 'package:CallSos/presentation/viewmodels/register_policia_viewmodel.dart';
import 'package:CallSos/data/models/agente_policia.dart';
import 'package:CallSos/data/models/enums/rol.dart';
import 'package:CallSos/data/models/enums/estado_agente.dart';

class AppProviders {
  static List<SingleChildWidget> get providers => [
        ChangeNotifierProvider(create: (_) => LoginViewModel()),
        ChangeNotifierProvider(create: (_) => ReporteViewModel()),
        ChangeNotifierProvider(create: (_) => RegisterPoliciaViewModel()),
        ChangeNotifierProvider(
          create: (_) => IncidenteViewModel(
            currentUser: AgentePolicia(
              id: 'comando-1',
              nombre: 'Oficial de Prueba',
              rol: Rol.JEFE_CAI,
              cai: 'CAI San Francisco',
              estadoAgente: EstadoAgente.DISPONIBLE,
            ),
          ),
        ),
      ];
}