import 'enums/estado_incidente.dart';

/// Registro inmutable de un hecho auditable de un incidente — espejo 1:1
/// de `com.callsos.backend.domain.model.AuditoriaIncidente`.
///
/// EPIC-07 (Auditorías e historiales — Timeline).
///
/// Igual que en el backend, este mismo modelo representa DOS clases de
/// hechos distintos (ver el docstring de la clase Java para el porqué de
/// no duplicar la tabla/modelo):
///
///   1. Transición de estado (uso original): [estadoAnterior]/[estadoNuevo]
///      llevan la transición real; [campo]/[valorAnteriorGenerico]/
///      [valorNuevoGenerico] quedan `null`.
///   2. Cambio de un campo genérico que NO es una transición de estado
///      (ej. "tipo" cambia de `ROBOS_O_ASALTOS` a `RIÑAS_O_PELEAS`):
///      [campo]/[valorAnteriorGenerico]/[valorNuevoGenerico] llevan el
///      hecho; [estadoAnterior] queda `null` y [estadoNuevo] lleva el
///      estado VIGENTE del incidente al momento del evento (no representa
///      una transición real).
///
/// Ver [esCambioGenerico] para distinguir ambos casos al renderizar.
class AuditoriaIncidente {
  final String incidenteId;

  /// `null` si es la creación inicial o un cambio de campo genérico.
  final EstadoIncidente? estadoAnterior;

  /// En un cambio de campo genérico, este es el estado VIGENTE del
  /// incidente al momento del evento — no representa una transición.
  final EstadoIncidente estadoNuevo;

  final String actorId;
  final String actorRol;
  final DateTime timestamp;
  final String detalle;

  /// `null` si es un cambio de estado normal (caso 1 arriba).
  final String? campo;
  final String? valorAnteriorGenerico;
  final String? valorNuevoGenerico;

  const AuditoriaIncidente({
    required this.incidenteId,
    this.estadoAnterior,
    required this.estadoNuevo,
    required this.actorId,
    required this.actorRol,
    required this.timestamp,
    required this.detalle,
    this.campo,
    this.valorAnteriorGenerico,
    this.valorNuevoGenerico,
  });

  /// Espejo de `AuditoriaIncidente.esCambioGenerico()` en el backend:
  /// `true` si este registro es un cambio de campo genérico (no una
  /// transición de estado).
  bool get esCambioGenerico => campo != null;

  factory AuditoriaIncidente.fromJson(Map<String, dynamic> json) {
    return AuditoriaIncidente(
      incidenteId: json['incidenteId'] as String,
      estadoAnterior: json['estadoAnterior'] != null
          ? estadoIncidenteFromJson(json['estadoAnterior'] as String)
          : null,
      estadoNuevo: estadoIncidenteFromJson(json['estadoNuevo'] as String),
      actorId: json['actorId'] as String,
      actorRol: json['actorRol'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      detalle: json['detalle'] as String? ?? '',
      campo: json['campo'] as String?,
      valorAnteriorGenerico: json['valorAnteriorGenerico'] as String?,
      valorNuevoGenerico: json['valorNuevoGenerico'] as String?,
    );
  }

  @override
  String toString() => 'AuditoriaIncidente(incidenteId: $incidenteId, '
      'actorRol: $actorRol, actorId: $actorId, timestamp: $timestamp, '
      'detalle: $detalle)';
}