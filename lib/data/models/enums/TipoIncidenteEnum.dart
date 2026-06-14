/// Tipos de incidente soportados por CallSOS.
///
/// F.0.2 — Alineación de enums con el backend.
///
/// Espejo de `com.callsos.backend.domain.enums.TipoIncidente` (Java).
///
/// ⚠️ NOTA TÉCNICA IMPORTANTE — carácter "Ñ":
/// El backend define el valor `RIÑAS_O_PELEAS`. Java permite letras Unicode
/// en identificadores de enum, pero **Dart no** (la gramática de Dart solo
/// admite `a-z`, `A-Z`, `_` y `$` en identificadores). Por eso este enum
/// usa `RINAS_O_PELEAS` (sin tilde/Ñ) como nombre Dart, y la correspondencia
/// con el valor real `"RIÑAS_O_PELEAS"` que envía/espera el backend se
/// resuelve de forma EXPLÍCITA mediante [_nombresBackend] — NO se puede usar
/// `.name` / `.byName(...)` directamente para este enum (a diferencia de
/// [EstadoIncidente] y [Rol], que sí son ASCII puro).
///
/// Usar siempre [TipoIncidenteJson.toJson] / [tipoIncidenteFromJson] para
/// convertir hacia/desde el backend.

enum TipoIncidenteEnum {
  RUIDO_EXCESIVO,
  ABUSO_INFANTIL,
  INCIDENTE_DE_TRANSITO,
  RINAS_O_PELEAS,
  VIOLENCIA_DOMESTICA,
  ROBOS_O_ASALTOS,
  ATENTADOS,
}

/// Mapeo explícito enum Dart → valor exacto esperado por el backend.
///
/// Todos los valores son idénticos a [TipoIncidenteEnum.name] EXCEPTO
/// [TipoIncidenteEnum.RINAS_O_PELEAS] → `"RIÑAS_O_PELEAS"`.
const Map<TipoIncidenteEnum, String> _nombresBackend = {
  TipoIncidenteEnum.RUIDO_EXCESIVO: 'RUIDO_EXCESIVO',
  TipoIncidenteEnum.ABUSO_INFANTIL: 'ABUSO_INFANTIL',
  TipoIncidenteEnum.INCIDENTE_DE_TRANSITO: 'INCIDENTE_DE_TRANSITO',
  TipoIncidenteEnum.RINAS_O_PELEAS: 'RIÑAS_O_PELEAS',
  TipoIncidenteEnum.VIOLENCIA_DOMESTICA: 'VIOLENCIA_DOMESTICA',
  TipoIncidenteEnum.ROBOS_O_ASALTOS: 'ROBOS_O_ASALTOS',
  TipoIncidenteEnum.ATENTADOS: 'ATENTADOS',
};

/// Helper de serialización para [TipoIncidenteEnum].
extension TipoIncidenteJson on TipoIncidenteEnum {
  /// Valor exacto que el backend espera/devuelve en JSON
  /// (campo `tipo` de `CrearIncidenteRequest` / `IncidenteResponse`).
  String toJson() => _nombresBackend[this]!;
}

/// Parsea el valor de `tipo` recibido del backend.
///
/// Lanza [FormatException] si el valor no corresponde a ninguno de los
/// tipos conocidos — un valor desconocido indica una desincronización
/// entre frontend y backend que NO debe silenciarse.
TipoIncidenteEnum tipoIncidenteFromJson(String value) {
  for (final entry in _nombresBackend.entries) {
    if (entry.value == value) return entry.key;
  }
  throw FormatException(
    'TipoIncidente desconocido recibido del backend: "$value". '
    'Verifica que frontend y backend estén alineados '
    '(com.callsos.backend.domain.enums.TipoIncidente).',
  );
}