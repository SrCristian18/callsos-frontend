# CallSOS — Deuda de Backend (F.0.7)

> **Contexto:** el backend no se modificará hasta que el frontend esté completo
> en gran medida. Este documento registra los 4 gaps conocidos entre lo que el
> frontend necesitará y lo que el backend expone hoy, para que cada fase
> posterior sepa exactamente qué mockear, stubear o dejar como "automático"
> sin bloquearse.
>
> Última actualización: F.0.7 (base de F.0 — Fundamentos de integración).

---

## Gap 1 — Registro de usuarios (denunciante / policía)

### Estado actual del backend
No existe ningún endpoint de registro. El backend solo expone
`POST /api/v1/auth/login` (credenciales → JWT). Los usuarios de prueba
están hardcodeados en `data.sql` (`juan.denunciante`, `pedro.agente`,
`operador.cai`, `comandante`, todos con password `password123`).

### Lo que el frontend necesitaría
- `POST /api/v1/denunciantes` — registro de denunciante (nombre, teléfono,
  email, password).
- Algún flujo de invitación con token para policías/CAI (la vista
  `RegisterPoliciaView` ya tiene el campo de "token de invitación" en la UI,
  pero el backend no valida ningún token; el `RegisterPoliciaViewModel`
  actual usa `"123456"` hardcodeado).

### Impacto en fases del frontend
- **F.1 / F.0.5:** `RegisterDenuncianteView` y `RegisterPoliciaView` quedan
  como stubs con mensaje "Próximamente". No bloquean ninguna otra fase.
- **Workaround hasta que el backend lo implemente:** usar las credenciales de
  `data.sql` para todas las pruebas de integración.

### Endpoint propuesto (para cuando se retome el backend)
```
POST /api/v1/auth/registro/denunciante
Body: { nombre, telefono, email, password }
→ 201 + AuthResponse { token, actorId, rol: "DENUNCIANTE" }

POST /api/v1/auth/registro/policia
Body: { tokenInvitacion, nombre, placa, password }
→ 201 + AuthResponse { token, actorId, rol: "AGENTE" | "OPERADOR_CAI" }
```

---

## Gap 2 — Catálogo de CAIs / selección manual al derivar

### Estado actual del backend
`AsignarCAIAIncidenteService` (`PATCH /api/v1/incidentes/{id}/derivar`)
selecciona automáticamente el CAI más cercano usando el algoritmo de
Haversine sobre los **26 CAIs reales de Cartagena** cargados en `data.sql`.
No existe endpoint para listar CAIs ni para que el operador elija
manualmente.

### Decisión de producto acordada (F.0.7)
Según lo confirmado durante el diseño de fases: el operador de Comando debe
poder **ver opciones candidatas y elegir**. Sin embargo, dado que el backend
asigna automáticamente, el frontend implementará en **F.2** el siguiente
patrón transitorio:

> Mostrar el CAI que el backend asignaría (el más cercano) como
> **"opción sugerida única"** con un botón "Confirmar derivación". Al
> confirmar, se dispara `PATCH /{id}/derivar` sin body adicional. Cuando
> el backend exponga un endpoint de candidatos, la UI ya tendrá el patrón
> de selección listo — solo cambia la fuente de datos.

### Impacto en F.2 (HomeComandoView)
- El botón "Derivar a CAI" abre un bottom sheet con **una sola opción**:
  "CAI más cercano (asignación automática)" + botón Confirmar.
- No se necesita ningún endpoint nuevo para este comportamiento transitorio.
- El texto del botón/diálogo debe dejar claro que es automático para no
  confundir al operador.

### Endpoint propuesto (para cuando se retome el backend)
```
GET /api/v1/cais/candidatos?incidenteId={id}&limite=3
→ 200 + [ { id, nombre, latitud, longitud, agentesDisponibles, distanciaKm } ]
```

---

## Gap 3 — Listado de agentes disponibles por CAI

### Estado actual del backend
`AsignarAgenteService` (`PATCH /api/v1/incidentes/{id}/asignar`) elige
automáticamente el primer agente con `EstadoAgente.DISPONIBLE` dentro de la
`UnidadPolicial` (CAI) asignada. No existe endpoint para listar agentes por
CAI ni para filtrarlos por disponibilidad.

### Decisión de producto acordada (F.0.7)
Mismo patrón que el Gap 2: el Operador CAI verá en **F.2** una opción única
"Agente disponible (asignación automática)" en un bottom sheet de selección,
que dispara `PATCH /{id}/asignar`. La UI del selector ya estará construida
para soportar múltiples opciones cuando el endpoint exista.

El `jefecai_widget.dart` actual tenía una lista mock hardcodeada
`["Agente Juan Perez", "Agente Maria Lopez", "Agente Carlos Ruiz"]` —
esa lista desaparece en F.2 y se reemplaza por la opción automática.

### Impacto en F.2 (HomeCAIView)
- Botón "Asignar Agente" → bottom sheet con una card: "Asignación automática
  al agente disponible" + Confirmar → `PATCH /{id}/asignar`.
- Si el backend devuelve 422 (`businessRule`) significa que no hay agentes
  disponibles en ese CAI — la UI debe mostrar `ApiException.message`.

### Endpoint propuesto (para cuando se retome el backend)
```
GET /api/v1/cais/{caiId}/agentes/disponibles
→ 200 + [ { id, nombre, placa, estadoAgente: "DISPONIBLE" } ]
```

---

## Gap 4 — Perfil de usuario (nombre y datos extendidos)

### Estado actual del backend
`AuthResponse` solo devuelve `{ token, actorId, rol }`. No hay endpoint de
perfil. El `actorId` es el ID de negocio del actor (ej. `"agente-001"`), no
un nombre legible.

### Impacto actual en el frontend
`SesionViewModel.nombrePlaceholder` genera una cadena de presentación
temporal: `"<Etiqueta del rol> • <primeros 8 chars del actorId>"`.
Ej: `"Agente de Policía • agente-0"`.

Este placeholder se muestra en:
- `AppBar` de `HomeAgenteView`, `HomeCAIView`, `HomeComandoView`,
  `HomeDenuncianteView`.
- `IncidenteView` (dispatch por rol, herencia de `AgentePolicia.nombre`).

### Impacto en fases del frontend
- No bloquea ninguna fase funcional (login, creación de incidentes, tracking,
  reportes).
- Impacto solo visual/UX: el usuario ve su rol + un fragmento de ID en vez
  de su nombre real.

### Endpoint propuesto (para cuando se retome el backend)
Opción A — enriquecer `AuthResponse` (cambio mínimo en backend):
```
POST /api/v1/auth/login
→ { token, actorId, rol, nombre, ...(otros campos opcionales) }
```

Opción B — endpoint de perfil separado (más RESTful):
```
GET /api/v1/actores/perfil          (usa actorId del JWT, sin parámetros)
→ { actorId, nombre, rol, cai?, placa? }
```

**Recomendación:** Opción A (cambio mínimo, un solo round-trip al iniciar
sesión). `SesionViewModel` ya tiene la estructura para almacenar un campo
`nombre` cuando el backend lo exponga — solo requiere añadirlo a
`AuthResult.fromJson` y a `flutter_secure_storage`.

---

## Resumen de impacto por fase

| Gap | Bloquea alguna fase | Workaround en frontend |
|-----|--------------------|-----------------------|
| 1 — Registro | No | Stubs "Próximamente" en RegisterView |
| 2 — Catálogo CAIs | No | Opción única "automática" en HomeComandoView (F.2) |
| 3 — Agentes disponibles | No | Opción única "automática" en HomeCAIView (F.2) |
| 4 — Perfil/nombre | No | `nombrePlaceholder` en SesionViewModel |

**Ninguno de los 4 gaps bloquea el desarrollo del frontend.** Las fases F.1
a F.7 pueden completarse íntegramente con los endpoints existentes y los
workarounds descritos. Cuando el frontend esté completo y se retome el
backend, los 4 endpoints propuestos arriba son el punto de partida.

---

## Referencia rápida — Endpoints existentes hoy

| Método | Ruta | Rol mínimo | Usado en |
|--------|------|-----------|---------|
| POST | `/auth/login` | público | F.0.4 SesionViewModel |
| POST | `/incidentes` | DENUNCIANTE | F.1 HomeDenuncianteView |
| GET | `/incidentes/{id}` | cualquiera | F.2 DetalleIncidenteView |
| GET | `/incidentes/{id}/estado` | cualquiera | F.2 polling |
| GET | `/incidentes/mis-incidentes` | DENUNCIANTE | F.2 HomeDenuncianteView |
| GET | `/incidentes/asignados` | AGENTE | F.2 HomeAgenteView |
| GET | `/incidentes/por-cai` | OPERADOR_CAI | F.2 HomeCAIView |
| PATCH | `/incidentes/{id}/derivar` | COMANDO | F.2 HomeComandoView |
| PATCH | `/incidentes/{id}/asignar` | OPERADOR_CAI | F.2 HomeCAIView |
| PATCH | `/incidentes/{id}/en-camino` | AGENTE | F.2 HomeAgenteView |
| PATCH | `/incidentes/{id}/atender` | AGENTE | F.2 HomeAgenteView |
| PATCH | `/incidentes/{id}/evaluar` | AGENTE | F.4 ReporteHallazgosView |
| PATCH | `/incidentes/{id}/cancelar` | DEN / COMANDO | F.2 |
| PATCH | `/denunciantes/{id}/token` | DENUNCIANTE | F.5 FCM |
| POST | `/reportes/hallazgos` | AGENTE | F.4 ReporteHallazgosView |
| POST | `/reportes/administrativo` | OPERADOR_CAI / COMANDO | futuro |
| GET | `/auditoria/incidente/{id}` | OPERADOR_CAI / COMANDO | futuro |
| WS | `/ws/websocket` (STOMP) | cualquiera autenticado | F.3 TrackingView |