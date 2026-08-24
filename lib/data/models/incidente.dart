import 'enums/estado_incidente.dart';
import 'enums/tipo_incidente_enum.dart';
import 'valueobject/ubicacion.dart';

/// Modelo de un incidente, espejo 1:1 de `IncidenteResponse`
/// (`com.callsos.backend.infrastructure.adapter.in.web.dto.IncidenteResponse`).
///
/// F.0.2 — Alineación de modelos con el backend.
///
/// Este modelo reemplaza a `IncidenteReportado` (`data/models/incidente_reportado.dart`)
/// como representación de un incidente proveniente del backend. Diferencias
/// clave respecto al modelo anterior:
///
/// - `tipo` es [TipoIncidenteEnum] (valor de dominio), no la clase de
///   presentación `TipoIncidente` (icono/color) — ver
///   `tipo_incidente_presentacion.dart` para la capa visual.
/// - `estado` es [EstadoIncidente] alineado con el backend (ver F.0.2).
/// - `latitud`/`longitud` numéricos (expuestos también como [ubicacion],
///   un [Ubicacion]), en vez del campo `ubicacion: String` libre del
///   modelo anterior.
/// - Incluye `denuncianteId`, `unidadPolicialId` y `nombreCAI`, presentes
///   en la respuesta del backend pero ausentes en `IncidenteReportado`.
///
/// `IncidenteReportado` se mantiene SIN MODIFICAR por ahora (lo siguen
/// usando `ReporteViewModel`/`IncidenteViewModel`/vistas actuales); su
/// reemplazo definitivo por [Incidente] ocurre en F.1/F.2 al reescribir
/// esas piezas según el roadmap acordado.
class Incidente {
  /// Identificador único del incidente (UUID/string generado por el backend).
  final String id;

  /// Momento en que se creó el incidente.
  final DateTime fechaHora;

  /// Tipo de incidente (valor de dominio — ver [catalogoTipos] para datos
  /// de presentación).
  final TipoIncidenteEnum tipo;

  /// Descripción libre escrita por el denunciante.
  final String descripcion;

  /// Estado actual dentro del ciclo de vida (ver [EstadoIncidente]).
  final EstadoIncidente estado;

  /// Latitud de la ubicación reportada.
  final double latitud;

  /// Longitud de la ubicación reportada.
  final double longitud;

  /// Id del denunciante que reportó el incidente.
  final String denuncianteId;

  /// Id de la unidad policial (CAI) a la que fue derivado, si ya ocurrió
  /// (`null` mientras el incidente está en estado `CREADO`).
  final String? unidadPolicialId;

  /// Nombre legible del CAI asignado, si ya ocurrió.
  final String? nombreCAI;

  /// Épica 7: id del agente con asignación ACTIVA sobre este incidente,
  /// si ya la hay (`null` en CREADO/DERIVADO_A_CAI). CAI y Comando lo
  /// necesitan para saber a qué topic de tracking suscribirse
  /// (`/topic/agente/{agenteId}/ubicacion`, ver Épica 3/[StompService]).
  final String? agenteId;

  /// Nombre legible del agente asignado, si ya ocurrió.
  final String? nombreAgente;

  const Incidente({
    required this.id,
    required this.fechaHora,
    required this.tipo,
    required this.descripcion,
    required this.estado,
    required this.latitud,
    required this.longitud,
    required this.denuncianteId,
    this.unidadPolicialId,
    this.nombreCAI,
    this.agenteId,
    this.nombreAgente,
  });

  /// Ubicación como value object (ver [Ubicacion]) — conveniencia para
  /// pasarla directamente a `flutter_map`/`stomp_dart_client` en F.3 sin
  /// reconstruirla manualmente desde [latitud]/[longitud].
  Ubicacion get ubicacion => Ubicacion(latitud: latitud, longitud: longitud);

  /// Espejo de `Incidente.estaActivo()` del backend: `true` si el incidente
  /// aún no llegó a un estado terminal (`FINALIZADO`/`CANCELADO`).
  bool get estaActivo => estado.estaActivo;

  Incidente copyWith({
    String? id,
    DateTime? fechaHora,
    TipoIncidenteEnum? tipo,
    String? descripcion,
    EstadoIncidente? estado,
    double? latitud,
    double? longitud,
    String? denuncianteId,
    String? unidadPolicialId,
    String? nombreCAI,
    String? agenteId,
    String? nombreAgente,
  }) {
    return Incidente(
      id: id ?? this.id,
      fechaHora: fechaHora ?? this.fechaHora,
      tipo: tipo ?? this.tipo,
      descripcion: descripcion ?? this.descripcion,
      estado: estado ?? this.estado,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
      denuncianteId: denuncianteId ?? this.denuncianteId,
      unidadPolicialId: unidadPolicialId ?? this.unidadPolicialId,
      nombreCAI: nombreCAI ?? this.nombreCAI,
      agenteId: agenteId ?? this.agenteId,
      nombreAgente: nombreAgente ?? this.nombreAgente,
    );
  }

  /// Construye un [Incidente] desde el JSON devuelto por el backend
  /// (`IncidenteResponse`, por ejemplo en `POST /api/v1/incidentes`,
  /// `GET /api/v1/incidentes/{id}`, `GET /api/v1/incidentes/mis-incidentes`,
  /// etc.).
  factory Incidente.fromJson(Map<String, dynamic> json) {
    return Incidente(
      id: json['id'] as String,
      fechaHora: DateTime.parse(json['fechaHora'] as String),
      tipo: tipoIncidenteFromJson(json['tipo'] as String),
      descripcion: json['descripcion'] as String? ?? '',
      estado: estadoIncidenteFromJson(json['estado'] as String),
      latitud: (json['latitud'] as num).toDouble(),
      longitud: (json['longitud'] as num).toDouble(),
      denuncianteId: json['denuncianteId'] as String,
      unidadPolicialId: json['unidadPolicialId'] as String?,
      nombreCAI: json['nombreCAI'] as String?,
      agenteId: json['agenteId'] as String?,
      nombreAgente: json['nombreAgente'] as String?,
    );
  }

  /// Serializa de vuelta al formato `IncidenteResponse`.
  ///
  /// Principalmente útil para tests de mapeo (round-trip) y para mocks de
  /// la capa de red en F.7; el frontend no suele necesitar enviar este
  /// objeto completo de vuelta al backend (las peticiones de creación usan
  /// `CrearIncidenteRequest`, más reducido — ver F.1).
  Map<String, dynamic> toJson() => {
        'id': id,
        'fechaHora': fechaHora.toIso8601String(),
        'tipo': tipo.toJson(),
        'descripcion': descripcion,
        'estado': estado.toJson(),
        'latitud': latitud,
        'longitud': longitud,
        'denuncianteId': denuncianteId,
        'unidadPolicialId': unidadPolicialId,
        'nombreCAI': nombreCAI,
        'agenteId': agenteId,
        'nombreAgente': nombreAgente,
      };

  @override
  String toString() =>
      'Incidente(id: $id, tipo: ${tipo.name}, estado: ${estado.name}, '
      'fechaHora: $fechaHora)';
}