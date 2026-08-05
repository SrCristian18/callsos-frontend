import 'enums/estado_agente.dart';

/// Agente disponible dentro de un CAI — espejo de
/// `AgenteDisponibleResponse` (Java) en `CaiController`.
///
/// FIX Gap 3 (deuda_backend.md): antes no existía forma de listar los
/// agentes disponibles de un CAI; HomeCAIView mostraba solo la opción
/// "asignación automática" sin detalle. Ahora se puede mostrar la lista
/// real antes de confirmar.
class AgenteDisponible {
  final String id;
  final String nombre;
  final String? telefono;
  final EstadoAgente estado;

  const AgenteDisponible({
    required this.id,
    required this.nombre,
    this.telefono,
    required this.estado,
  });

  factory AgenteDisponible.fromJson(Map<String, dynamic> json) {
    return AgenteDisponible(
      id: json['id'] as String,
      nombre: json['nombre'] as String,
      telefono: json['telefono'] as String?,
      estado: EstadoAgente.values.byName(json['estado'] as String),
    );
  }
}