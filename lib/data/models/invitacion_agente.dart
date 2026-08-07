/// Invitación de agente recién generada — espejo de `InvitacionResponse`
/// (Java) en `InvitacionController`.
class InvitacionAgente {
  final String token;
  final String unidadPolicialId;
  final DateTime fechaExpiracion;

  const InvitacionAgente({
    required this.token,
    required this.unidadPolicialId,
    required this.fechaExpiracion,
  });

  factory InvitacionAgente.fromJson(Map<String, dynamic> json) {
    return InvitacionAgente(
      token: json['token'] as String,
      unidadPolicialId: json['unidadPolicialId'] as String,
      fechaExpiracion: DateTime.parse(json['fechaExpiracion'] as String),
    );
  }
}