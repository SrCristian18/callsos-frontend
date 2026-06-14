// ignore_for_file: constant_identifier_names

/// Roles de actor en CallSOS.
///
/// F.0.2 — Alineación de enums con el backend.
///
/// Espejo EXACTO (mismos nombres) de:
/// `com.callsos.backend.domain.enums.RolUsuario`
///
/// IMPORTANTE: el backend coloca el rol en el claim `rol` del JWT
/// (ver `JwtService`/`JwtAuthFilter`) y lo serializa con `.name()`. Por lo
/// tanto los valores de este enum deben coincidir EXACTAMENTE con los que
/// emite el backend — cualquier diferencia rompería en silencio la
/// autorización del lado del cliente (F.0.4 — gestión de sesión).
///
/// MIGRACIÓN (F.0.2): este enum reemplaza al anterior
/// `{COMANDO, JEFE_CAI, AGENTE_POLICIA}`. Tabla de migración aplicada en el
/// código existente:
///
/// | Valor anterior   | Valor nuevo    |
/// |------------------|----------------|
/// | (nuevo)          | DENUNCIANTE    |
/// | AGENTE_POLICIA   | AGENTE         |
/// | JEFE_CAI         | OPERADOR_CAI   |
/// | COMANDO          | COMANDO        |
///
/// NOTA DE NEGOCIO: "OPERADOR_CAI" es el nombre del rol en el backend; la
/// etiqueta visible en la UI puede seguir siendo "Jefe de CAI" / "Operador
/// CAI" indistintamente — ver [RolDisplay.etiqueta] — pero el VALOR del
/// enum (lo que se compara, persiste y envía) es siempre `OPERADOR_CAI`.
enum Rol {
  DENUNCIANTE,
  AGENTE,
  OPERADOR_CAI,
  COMANDO,
}

/// Helpers de (de)serialización para [Rol].
///
/// Al igual que [EstadoIncidente], todos los valores son ASCII en
/// mayúsculas y coinciden carácter a carácter con el claim `rol` del JWT,
/// por lo que `.name` / `Rol.values.byName(...)` son seguros de usar
/// directamente.
extension RolJson on Rol {
  /// Valor exacto que el backend espera/devuelve (JSON y claim del JWT).
  String toJson() => name;
}

/// Etiquetas de presentación para cada [Rol].
///
/// Estas cadenas son SOLO para mostrar en la UI; nunca deben usarse para
/// comparar, persistir o enviar al backend (para eso usar el valor del
/// enum directamente, ver [RolJson.toJson]).
extension RolDisplay on Rol {
  String get etiqueta {
    switch (this) {
      case Rol.DENUNCIANTE:
        return 'Denunciante';
      case Rol.AGENTE:
        return 'Agente de Policía';
      case Rol.OPERADOR_CAI:
        return 'Operador CAI';
      case Rol.COMANDO:
        return 'Comando';
    }
  }
}

/// Parsea el valor de `rol` recibido del backend (JSON o claim del JWT).
///
/// Lanza [FormatException] si el valor no corresponde a ninguno de los
/// roles conocidos — un valor desconocido indica una desincronización
/// entre frontend y backend que NO debe silenciarse.
Rol rolFromJson(String value) {
  try {
    return Rol.values.byName(value);
  } on ArgumentError {
    throw FormatException(
      'Rol desconocido recibido del backend: "$value". '
      'Verifica que frontend y backend estén alineados '
      '(com.callsos.backend.domain.enums.RolUsuario).',
    );
  }
}