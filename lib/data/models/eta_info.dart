/// Categoría de distancia del agente al incidente — espejo de
/// `com.callsos.backend.domain.enums.CategoriaDistancia`.
///
/// Épica 4/7: el backend NUNCA expone metros/km exactos ni coordenadas,
/// solo esta categorización — ver `EtaInfo` (backend) para el porqué.
enum CategoriaDistancia {
  MENOS_DE_1_KM,
  ENTRE_1_Y_3_KM,
  ENTRE_3_Y_10_KM,
  MAS_DE_10_KM;

  static CategoriaDistancia? fromJson(String? value) {
    if (value == null) return null;
    return CategoriaDistancia.values.byName(value);
  }

  String? toJson() => name;

  /// Texto legible en español para mostrar junto a los minutos estimados
  /// (ej. "~8 min · a menos de 1 km").
  String get etiqueta {
    switch (this) {
      case CategoriaDistancia.MENOS_DE_1_KM:
        return 'a menos de 1 km';
      case CategoriaDistancia.ENTRE_1_Y_3_KM:
        return 'entre 1 y 3 km';
      case CategoriaDistancia.ENTRE_3_Y_10_KM:
        return 'entre 3 y 10 km';
      case CategoriaDistancia.MAS_DE_10_KM:
        return 'a más de 10 km';
    }
  }
}

/// Tiempo estimado de llegada del agente — espejo 1:1 de `EtaResponse`
/// (`GET /incidentes/{id}/eta`) y del payload de
/// `/topic/incidente/{id}/eta` (`PublicarUbicacionAgenteService.EtaPublicada`),
/// que comparten exactamente la misma forma.
///
/// Épica 7: reemplaza el mapa de tracking en vivo para el DENUNCIANTE
/// (retirado por P6, Épica 3) — el denunciante ya no ve la posición GPS
/// cruda del agente, solo este valor derivado (minutos + categoría de
/// distancia), consistente con la garantía de seguridad que ya
/// documenta `EtaInfo` en el backend: este objeto, por diseño, no puede
/// llevar lat/lon porque el campo mismo no existe.
///
/// `minutosEstimados`/`categoriaDistancia` son ambos `null` cuando el
/// backend no tiene datos suficientes todavía (agente aún no reportó
/// posición, o el incidente no está en `AGENTE_EN_CAMINO`) — no un 0 ni
/// un valor centinela.
class EtaInfo {
  final int? minutosEstimados;
  final CategoriaDistancia? categoriaDistancia;

  const EtaInfo({this.minutosEstimados, this.categoriaDistancia});

  const EtaInfo.sinDatos()
      : minutosEstimados = null,
        categoriaDistancia = null;

  bool get tieneDatos => minutosEstimados != null;

  factory EtaInfo.fromJson(Map<String, dynamic> json) {
    return EtaInfo(
      minutosEstimados: json['minutosEstimados'] as int?,
      categoriaDistancia:
          CategoriaDistancia.fromJson(json['categoriaDistancia'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
        'minutosEstimados': minutosEstimados,
        'categoriaDistancia': categoriaDistancia?.toJson(),
      };

  @override
  String toString() => tieneDatos
      ? 'EtaInfo(~$minutosEstimados min, ${categoriaDistancia!.name})'
      : 'EtaInfo(sinDatos)';
}