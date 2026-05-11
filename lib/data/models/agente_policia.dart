import 'package:CallSos/data/models/enums/estado_agente.dart';
import 'package:CallSos/data/models/enums/rol.dart';

class AgentePolicia {
  final String id;
  final String nombre;
  final Rol rol;
  final EstadoAgente estadoAgente;
  final String? cai; //Si se modela Comando, estos no están obligados a definir su CAI, porque no tienen

  AgentePolicia({
    required this.id,
    required this.nombre,
    required this.rol,
    required this.estadoAgente,
    this.cai,
  });
}