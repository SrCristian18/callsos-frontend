// ignore_for_file: constant_identifier_names

/// Estados del ciclo de vida de un [Incidente].
///
/// F.0.2 — Alineación de enums con el backend.
///
/// Espejo EXACTO (mismos nombres) de:
/// `com.callsos.backend.domain.enums.EstadoIncidente`
///
/// Máquina de estados implementada en `Incidente.java` (backend):
///
/// ```
/// CREADO
///   │  (Comando deriva al CAI más cercano — PATCH /{id}/derivar)
///   ▼
/// DERIVADO_A_CAI
///   │  (CAI asigna agente disponible — PATCH /{id}/asignar)
///   ▼
/// AGENTE_ASIGNADO
///   │  (agente confirma salida — PATCH /{id}/en-camino)
///   ▼
/// AGENTE_EN_CAMINO
///   │  (agente llega y atiende — PATCH /{id}/atender)
///   ▼
/// EN_ATENCION
///   │  (agente finaliza y evalúa — PATCH /{id}/evaluar)
///   ▼
/// FINALIZADO
/// ```
///
/// Desde cualquier estado activo (todos excepto FINALIZADO y CANCELADO)
/// se puede transicionar a `CANCELADO` (denunciante o Comando —
/// PATCH /{id}/cancelar).
///
/// MIGRACIÓN (F.0.2): este enum reemplaza al anterior
/// `{RECIBIDO, PENDIENTE, CAI_ASIGNADO, AGENTE_ASIGNADO, EN_PROCESO,
/// COMPLETADO, CANCELADO, INCOMPLETO}`, que no correspondía al backend.
/// Tabla de migración aplicada en el código existente:
///
/// | Valor anterior   | Valor nuevo       |
/// |------------------|-------------------|
/// | RECIBIDO         | CREADO            |
/// | PENDIENTE        | (eliminado)       |
/// | CAI_ASIGNADO     | DERIVADO_A_CAI    |
/// | AGENTE_ASIGNADO  | AGENTE_ASIGNADO   |
/// | (nuevo)          | AGENTE_EN_CAMINO  |
/// | EN_PROCESO       | EN_ATENCION       |
/// | COMPLETADO       | FINALIZADO        |
/// | CANCELADO        | CANCELADO         |
/// | INCOMPLETO       | (eliminado)       |
///
/// Como todos los valores son ASCII en mayúsculas y coinciden carácter a
/// carácter con el JSON que serializa el backend (Jackson serializa enums
/// Java por `.name()`), la (de)serialización puede hacerse de forma directa
/// y segura con `.name` / `EstadoIncidente.values.byName(...)`. Se exponen
/// además [EstadoIncidenteJson.fromJson] / [toJson] como wrappers explícitos
/// para que el resto del código no dependa de la API de `enum` directamente
/// (facilita el día que se requiera un mapeo distinto).
enum EstadoIncidente {
  CREADO,
  DERIVADO_A_CAI,
  AGENTE_ASIGNADO,
  AGENTE_EN_CAMINO,
  EN_ATENCION,
  FINALIZADO,
  CANCELADO,
}

/// Helpers de (de)serialización y de dominio para [EstadoIncidente].
extension EstadoIncidenteJson on EstadoIncidente {
  /// Valor exacto que el backend espera/devuelve en JSON.
  String toJson() => name;

  /// Espejo de `Incidente.estaActivo()` en el backend: todo estado que no
  /// sea terminal (`FINALIZADO` o `CANCELADO`) se considera activo.
  bool get estaActivo =>
      this != EstadoIncidente.FINALIZADO && this != EstadoIncidente.CANCELADO;

  /// `true` si el incidente ya terminó su ciclo de vida (de forma exitosa
  /// o por cancelación). Complemento de [estaActivo].
  bool get esTerminal => !estaActivo;
}

/// Parsea el valor de `estado` recibido del backend.
///
/// Lanza [FormatException] si el valor no corresponde a ninguno de los
/// estados conocidos — esto es intencional: un valor desconocido indica
/// una desincronización entre frontend y backend que NO debe silenciarse.
EstadoIncidente estadoIncidenteFromJson(String value) {
  try {
    return EstadoIncidente.values.byName(value);
  } on ArgumentError {
    throw FormatException(
      'EstadoIncidente desconocido recibido del backend: "$value". '
      'Verifica que frontend y backend estén alineados '
      '(com.callsos.backend.domain.enums.EstadoIncidente).',
    );
  }
}