/// Mensaje de actualización de un incidente recibido del backend vía STOMP.
///
/// Espejo de
/// `ActualizacionIncidenteWebSocketListener.ActualizacionPublicada` (Java):
/// ```json
/// {
///   "tipoEvento": "TIPO_ACTUALIZADO",
///   "valorAnterior": "ROBOS_O_ASALTOS",
///   "valorNuevo": "RIÑAS_O_PELEAS",
///   "timestamp": "2026-06-14T10:05:00"
/// }
/// ```
///
/// Épica 8 (hallazgo #4): payload genérico deliberadamente, igual que en
/// el backend — si en el futuro se agregan otras actualizaciones al mismo
/// topic (ej. reasignación de CAI), este modelo no necesita cambiar, solo
/// ramificar por [tipoEvento] en quien lo consume (ver
/// `DetalleIncidenteView._onActualizacionRecibida`).
///
/// `valorAnterior`/`valorNuevo` son `String?` deliberadamente (no un enum
/// tipado): distintos `tipoEvento` futuros podrían llevar valores de
/// dominio distintos (tipo de incidente, id de CAI, etc.) — es
/// responsabilidad de quien interpreta el mensaje convertir el valor
/// correcto según [tipoEvento] (ver [tipoIncidenteFromJson] para el caso
/// `TIPO_ACTUALIZADO`).
class ActualizacionMensaje {
  final String tipoEvento;
  final String? valorAnterior;
  final String? valorNuevo;
  final String timestamp;

  const ActualizacionMensaje({
    required this.tipoEvento,
    this.valorAnterior,
    this.valorNuevo,
    required this.timestamp,
  });

  factory ActualizacionMensaje.fromJson(Map<String, dynamic> json) {
    return ActualizacionMensaje(
      tipoEvento: json['tipoEvento'] as String? ?? '',
      valorAnterior: json['valorAnterior'] as String?,
      valorNuevo: json['valorNuevo'] as String?,
      timestamp: json['timestamp'] as String? ?? '',
    );
  }

  /// `true` cuando este mensaje representa un cambio de tipo de
  /// incidente — el único `tipoEvento` que el backend publica hoy (ver
  /// `ActualizacionIncidenteWebSocketListener.onTipoActualizado`).
  bool get esTipoActualizado => tipoEvento == 'TIPO_ACTUALIZADO';

  @override
  String toString() =>
      'ActualizacionMensaje(tipoEvento: $tipoEvento, valorAnterior: '
      '$valorAnterior, valorNuevo: $valorNuevo, timestamp: $timestamp)';
}