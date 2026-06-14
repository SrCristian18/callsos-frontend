/// Value object de ubicación geográfica (latitud/longitud).
///
/// F.0.2 — Alineación de modelos con el backend.
///
/// Espejo de `com.callsos.backend.domain.valueobject.Ubicacion`: valida que
/// la latitud esté en el rango [-90, 90] y la longitud en [-180, 180],
/// lanzando [ArgumentError] si no es así — igual que el VO del backend, que
/// rechaza coordenadas inválidas en su constructor.
///
/// Usos previstos:
/// - F.1: capturar la posición GPS del denunciante al crear un incidente
///   (`CrearIncidenteRequest.ubicacion`, DTO `UbicacionDto` del backend).
/// - F.3: posiciones del agente durante el tracking en tiempo real
///   (canal WebSocket `/app/ubicacion/{incidenteId}`).
///
/// Es un VO inmutable con igualdad por valor (`==`/`hashCode`), igual que
/// su contraparte en el backend.
class Ubicacion {
  final double latitud;
  final double longitud;

  Ubicacion({required this.latitud, required this.longitud}) {
    if (latitud < -90 || latitud > 90) {
      throw ArgumentError.value(
        latitud,
        'latitud',
        'Debe estar entre -90 y 90 grados.',
      );
    }
    if (longitud < -180 || longitud > 180) {
      throw ArgumentError.value(
        longitud,
        'longitud',
        'Debe estar entre -180 y 180 grados.',
      );
    }
  }

  /// Construye una [Ubicacion] desde el JSON devuelto por el backend.
  ///
  /// Soporta tanto `{"latitud": ..., "longitud": ...}` (forma usada en
  /// `UbicacionDto` / `CrearIncidenteRequest`) como los campos planos
  /// `latitud`/`longitud` que trae `IncidenteResponse` directamente en su
  /// raíz (ver [Incidente.fromJson], que construye su propia [Ubicacion]
  /// a partir de esos campos planos sin pasar por este factory).
  factory Ubicacion.fromJson(Map<String, dynamic> json) {
    return Ubicacion(
      latitud: (json['latitud'] as num).toDouble(),
      longitud: (json['longitud'] as num).toDouble(),
    );
  }

  /// Serializa al formato `UbicacionDto` esperado por
  /// `CrearIncidenteRequest` (`POST /api/v1/incidentes`) y por los mensajes
  /// STOMP de tracking (F.3).
  Map<String, dynamic> toJson() => {
        'latitud': latitud,
        'longitud': longitud,
      };

  @override
  bool operator ==(Object other) =>
      other is Ubicacion &&
      other.latitud == latitud &&
      other.longitud == longitud;

  @override
  int get hashCode => Object.hash(latitud, longitud);

  @override
  String toString() => 'Ubicacion(latitud: $latitud, longitud: $longitud)';
}