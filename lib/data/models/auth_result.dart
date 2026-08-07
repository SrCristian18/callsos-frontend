import 'enums/rol.dart';

/// Resultado de un login exitoso, espejo de `AuthResponse`
/// (`com.callsos.backend.infrastructure.adapter.in.web.dto.AuthResponse`).
///
/// F.0.3 — Capa de red.
///
/// - [token]: JWT a usar en `Authorization: Bearer <token>` en el resto de
///   endpoints (ver [ITokenProvider] / `ApiClient`).
/// - [actorId]: ID de negocio del denunciante/agente/unidad — es el que se
///   usa, por ejemplo, para `PATCH /denunciantes/{actorId}/token` (F.5).
/// - [rol]: rol del actor autenticado (ver [Rol]), viene también como claim
///   `rol` dentro del JWT.
/// - [nombre]: FIX Gap 4 (deuda_backend.md) — nombre real del usuario.
///   Nullable: cuentas semilla anteriores al fix de backend (tabla
///   `usuarios`, columna `nombre` agregada en `05_perfil_usuario.sql`)
///   pueden no tenerlo. `SesionViewModel.nombreMostrar` hace fallback a un
///   placeholder cuando viene null.
class AuthResult {
  final String token;
  final String actorId;
  final Rol rol;
  final String? nombre;

  const AuthResult({
    required this.token,
    required this.actorId,
    required this.rol,
    this.nombre,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      token: json['token'] as String,
      actorId: json['actorId'] as String,
      rol: rolFromJson(json['rol'] as String),
      nombre: json['nombre'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'token': token,
        'actorId': actorId,
        'rol': rol.toJson(),
        'nombre': nombre,
      };

  @override
  String toString() => 'AuthResult(actorId: $actorId, rol: ${rol.name})';
}