# CallSOS — Deuda de Backend (F.0.7)

> ## ⚠️ ESTADO ACTUAL (actualizado en validación end-to-end / Épica 8): LOS 4 GAPS YA ESTÁN RESUELTOS
>
> Este documento se dejó intacto por valor histórico (documenta las decisiones de
> producto tomadas mientras cada gap estuvo abierto — útil para entender POR QUÉ
> ciertas pantallas se diseñaron como se diseñaron), pero **ya no refleja el
> estado real del sistema**. Verificado contra el código real en `dev` (ambos
> repos) en esta fecha:
>
> | Gap | Estado | Evidencia |
> |---|---|---|
> | 1 — Registro | ✅ Resuelto | `AuthController` (`/auth/registro/denunciante`, `/auth/registro/agente` con token de invitación) + `RegisterDenuncianteView`/`RegisterPoliciaView` ya conectadas vía `SesionViewModel.registrarDenunciante`/`registrarAgente` |
> | 2 — Catálogo CAIs / listado Comando | ✅ Resuelto (la parte urgente) | `GET /incidentes/por-estado?estado=CREADO` (`ConsultarIncidentesPorEstadoService`) + `HomeComandoView` ya lo consume vía `service.porEstado(...)`. El catálogo de candidatos (`GET /cais/candidatos`) sigue sin existir, pero nunca fue el bloqueante real — sigue la asignación automática al CAI más cercano |
> | 3 — Agentes disponibles | ✅ Resuelto | `GET /cais/{caiId}/agentes/disponibles` + `HomeCAIView` ya lo consume vía `caiService.agentesDisponibles(...)` |
> | 4 — Perfil/nombre | ✅ Resuelto | `usuarios.nombre` (`05_perfil_usuario.sql`) + `AuthResponse.nombre` + `AuthResult.nombre` (Flutter) |
>
> **Sub-gap nuevo, menor, NO documentado originalmente aquí:** el tab
> "Delegados" de `HomeComandoView` (historial de incidentes ya derivados)
> todavía muestra un placeholder — no hay endpoint para listar incidentes por
> más de un estado a la vez ni un historial agregado para Comando. Ver el
> comentario en `home_comando_view.dart` línea ~277. Menor: Comando puede
> igual ver cualquier incidente derivado desde su detalle. No bloqueante.
>
> **Nota operativa importante encontrada en esta misma revisión:** las
> migraciones `05_perfil_usuario.sql`, `06_epica2_auditoria_generica.sql` y
> `07_epica5_token_fcm_agente_cai.sql` son `ALTER TABLE`, NO parte de
> `01_schema.sql`. Como `docker-compose.yml` monta `database/` en
> `/docker-entrypoint-initdb.d` sobre un volumen con nombre persistente
> (`mysql_data`), MySQL **solo las ejecuta la primera vez que el volumen está
> vacío** — cualquier entorno local levantado ANTES de que estos 3 scripts
> existieran necesita correrlos a mano (o recrear el volumen) o el login
> falla con 500 para todos los roles (`usuarios.nombre` no existe todavía).
>
> El resto del documento se conserva sin cambios, tal como se escribió
> cuando estos gaps estaban abiertos.

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

## Gap 2 — Catálogo de CAIs / selección manual al derivar / **listado para Comando**

### Estado actual del backend
`AsignarCAIAIncidenteService` (`PATCH /api/v1/incidentes/{id}/derivar`)
selecciona automáticamente el CAI más cercano usando el algoritmo de
Haversine sobre los **26 CAIs reales de Cartagena** cargados en `data.sql`.
No existe endpoint para listar CAIs ni para que el operador elija
manualmente.

### 🔴 ACTUALIZACIÓN — hallazgo de la validación end-to-end real
Durante la validación end-to-end (post F.0–F.7) se confirmó un problema
más grave de lo documentado originalmente: **no existe NINGÚN endpoint
que permita a COMANDO listar los incidentes pendientes de derivar.**

Los 3 endpoints de consulta existentes filtran por `actorId` del JWT
contra un campo específico del incidente, y ninguno aplica al rol COMANDO:

| Endpoint | Filtra por | Por qué no sirve para COMANDO |
|---|---|---|
| `GET /mis-incidentes` | `denuncianteId == actorId` | El comandante no es denunciante |
| `GET /asignados` | `agenteId == actorId` | El comandante no es agente |
| `GET /por-cai` | `unidadPolicialId == actorId` | El comandante no es una unidad policial. Además, un incidente recién `CREADO` **nunca** tiene `unidadPolicialId` (es justo el dato que Comando debe asignar) — el endpoint es incompatible incluso si el actorId coincidiera |

**Confirmado contra el backend real**: un incidente en estado `CREADO`
tiene `unidadPolicialId: null` y `nombreCAI: null` — no hay ningún campo
en el modelo de incidente que lo asocie al comandante.

### Decisión de producto acordada (F.0.7, vigente para selección de CAI)
El operador de Comando debe poder **ver opciones candidatas y elegir**.
Dado que el backend asigna automáticamente, el bottom sheet de
confirmación de derivación mantiene el patrón:

> Mostrar el CAI que el backend asignaría (el más cercano) como
> **"opción sugerida única"** con un botón "Confirmar derivación". Al
> confirmar, se dispara `PATCH /{id}/derivar` sin body adicional.

### Workaround aplicado en HomeComandoView (post validación end-to-end)
Como no hay forma de listar, `HomeComandoView` se rediseñó con:
1. Un aviso visible explicando la limitación (no se simula ni se oculta).
2. Un **buscador por ID de incidente** (`GET /{id}`, sin restricción de
   rol) — el comandante pega/escribe el ID del incidente y puede verlo
   y derivarlo desde ahí.
3. El ID debe obtenerse hoy por un canal externo al flujo (ej. consulta
   directa a base de datos, logs del backend, o coordinación manual con
   el denunciante/operador) — **no es una solución de UX aceptable a
   largo plazo**, es el único camino viable sin tocar el backend.

### Impacto en F.2 (HomeComandoView)
- El tab "Reportados" (listado automático) se eliminó — era inviable.
- Se reemplazó por búsqueda manual + acción "Derivar a CAI" funcional.

- El texto del botón/diálogo debe dejar claro que es automático para no
  confundir al operador.

### Endpoints propuestos (para cuando se retome el backend)

**Para el listado de Comando (más urgente que el catálogo de candidatos):**
```
GET /api/v1/incidentes?estado=CREADO
→ requiere rol COMANDO, sin filtro de actorId (Comando ve todos los
  incidentes pendientes de derivar, sin importar quién los reportó)
→ 200 + [ IncidenteResponse ]
```

**Para selección manual de CAI (mejora de UX, no bloqueante):**
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