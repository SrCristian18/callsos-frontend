import '../models/enums/estado_incidente.dart';
import '../models/enums/tipo_incidente_enum.dart';
import '../models/incidente.dart';
import '../models/valueobject/ubicacion.dart';
import 'api_client.dart';

/// Servicio de incidentes — espejo de `IncidenteController`
/// (`/api/v1/incidentes`).
///
/// F.0.3 — Capa de red.
///
/// Agrupa:
/// - Consultas (lectura): [crear], [consultar], [consultarEstado],
///   [misIncidentes], [asignados], [porCai].
/// - Transiciones de estado (escritura, todas devuelven `204 No Content`
///   en el backend -> `Future<void>` aquí): [cambiarEstado], [derivar],
///   [asignar], [enCamino], [atender], [evaluar], [cancelar].
///
/// Todas las operaciones lanzan [ApiException] en caso de error (ver
/// `api_exception.dart`); en particular, una transición inválida para el
/// estado actual del incidente (ej. intentar `atender` un incidente que
/// aún no tiene agente asignado) resulta en
/// `ApiException(type: ApiExceptionType.businessRule, statusCode: 422)`,
/// espejo de la `IllegalStateException` que lanza la máquina de estados de
/// `Incidente` en el backend.
abstract class IIncidenteService {
  /// `POST /incidentes` — crea un nuevo incidente.
  ///
  /// Body enviado (espejo de `CrearIncidenteRequest`):
  /// ```json
  /// {
  ///   "denuncianteId": "...",
  ///   "tipo": "ROBOS_O_ASALTOS",
  ///   "descripcion": "...",
  ///   "ubicacion": {"latitud": ..., "longitud": ...}
  /// }
  /// ```
  /// Devuelve el [Incidente] creado (estado inicial `CREADO`).
  Future<Incidente> crear({
    required String denuncianteId,
    required TipoIncidenteEnum tipo,
    required String descripcion,
    required Ubicacion ubicacion,
  });

  /// `GET /incidentes/{id}` — detalle completo del incidente.
  Future<Incidente> consultar(String id);

  /// `GET /incidentes/{id}/estado` — solo el estado actual.
  ///
  /// El backend devuelve el enum serializado como string JSON plano
  /// (ej. `"AGENTE_EN_CAMINO"`), no envuelto en un objeto.
  Future<EstadoIncidente> consultarEstado(String id);

  /// `GET /incidentes/mis-incidentes` — historial del denunciante
  /// autenticado (el `actorId` se toma del JWT en el backend, no se envía
  /// explícitamente).
  Future<List<Incidente>> misIncidentes();

  /// `GET /incidentes/asignados` — cola de trabajo del agente autenticado.
  Future<List<Incidente>> asignados();

  /// `GET /incidentes/por-cai` — panel de operaciones del CAI autenticado.
  Future<List<Incidente>> porCai();

  /// FIX Gap 2 — nuevo endpoint para COMANDO.
  /// GET /incidentes/por-estado?estado={estado}
  Future<List<Incidente>> porEstado(EstadoIncidente estado);

  /// `PATCH /incidentes/{id}/estado` — cambio de estado genérico.
  ///
  /// Body: `{"nuevoEstado": "<EstadoIncidente>"}`. Usado principalmente
  /// para `CANCELADO` desde roles distintos al denunciante (Comando), o
  /// para correcciones administrativas. Para el flujo normal, prefiere los
  /// métodos específicos ([derivar], [asignar], etc.), que documentan
  /// mejor la intención y no requieren conocer el nombre exacto del estado
  /// destino.
  Future<void> cambiarEstado(String id, EstadoIncidente nuevoEstado);

  /// `PATCH /incidentes/{id}/derivar` — Comando deriva el incidente al CAI
  /// más cercano (`CREADO` -> `DERIVADO_A_CAI`). El backend elige el CAI
  /// automáticamente (Haversine); no se envía body.
  Future<void> derivar(String id);

  /// `PATCH /incidentes/{id}/asignar` — el CAI asigna un agente disponible
  /// (`DERIVADO_A_CAI` -> `AGENTE_ASIGNADO`). El backend elige el agente
  /// automáticamente; no se envía body.
  ///
  /// NOTA (decisión de producto, ver F.0.7): el operador debe poder elegir
  /// entre opciones, pero el backend actual no expone un endpoint de
  /// candidatos — esta llamada dispara la asignación automática del
  /// backend. F.2 documentará esto como deuda de backend.
  Future<void> asignar(String id);

  /// `PATCH /incidentes/{id}/en-camino` — el agente confirma que va en
  /// camino (`AGENTE_ASIGNADO` -> `AGENTE_EN_CAMINO`).
  Future<void> enCamino(String id);

  /// `PATCH /incidentes/{id}/atender` — el agente llega y comienza la
  /// atención (`AGENTE_EN_CAMINO` -> `EN_ATENCION`).
  Future<void> atender(String id);

  /// `PATCH /incidentes/{id}/evaluar` — el agente finaliza la atención
  /// (`EN_ATENCION` -> `FINALIZADO`).
  Future<void> evaluar(String id);

  /// `PATCH /incidentes/{id}/cancelar` — cancela el incidente
  /// (cualquier estado activo -> `CANCELADO`).
  Future<void> cancelar(String id);
}

class IncidenteService implements IIncidenteService {
  final IApiClient _client;

  const IncidenteService(this._client);

  @override
  Future<Incidente> crear({
    required String denuncianteId,
    required TipoIncidenteEnum tipo,
    required String descripcion,
    required Ubicacion ubicacion,
  }) async {
    final data = await _client.post(
      '/incidentes',
      data: {
        'denuncianteId': denuncianteId,
        'tipo': tipo.toJson(),
        'descripcion': descripcion,
        'ubicacion': ubicacion.toJson(),
      },
    );
    return Incidente.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<Incidente> consultar(String id) async {
    final data = await _client.get('/incidentes/$id');
    return Incidente.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<EstadoIncidente> consultarEstado(String id) async {
    final data = await _client.get('/incidentes/$id/estado');
    return estadoIncidenteFromJson(data as String);
  }

  @override
  Future<List<Incidente>> misIncidentes() async {
    final data = await _client.get('/incidentes/mis-incidentes');
    return _aListaDeIncidentes(data);
  }

  @override
  Future<List<Incidente>> asignados() async {
    final data = await _client.get('/incidentes/asignados');
    return _aListaDeIncidentes(data);
  }

  @override
  Future<List<Incidente>> porCai() async {
    final data = await _client.get('/incidentes/por-cai');
    return _aListaDeIncidentes(data);
  }

  @override
  Future<List<Incidente>> porEstado(EstadoIncidente estado) async {
    final data = await _client.get(
        '/incidentes/por-estado?estado=${estado.name}');
    return _aListaDeIncidentes(data);
  }

  List<Incidente> _aListaDeIncidentes(dynamic data) {
    return (data as List<dynamic>)
        .map((e) => Incidente.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> cambiarEstado(String id, EstadoIncidente nuevoEstado) async {
    await _client.patch(
      '/incidentes/$id/estado',
      data: {'nuevoEstado': nuevoEstado.toJson()},
    );
  }

  @override
  Future<void> derivar(String id) async {
    await _client.patch('/incidentes/$id/derivar');
  }

  @override
  Future<void> asignar(String id) async {
    await _client.patch('/incidentes/$id/asignar');
  }

  @override
  Future<void> enCamino(String id) async {
    await _client.patch('/incidentes/$id/en-camino');
  }

  @override
  Future<void> atender(String id) async {
    await _client.patch('/incidentes/$id/atender');
  }

  @override
  Future<void> evaluar(String id) async {
    await _client.patch('/incidentes/$id/evaluar');
  }

  @override
  Future<void> cancelar(String id) async {
    await _client.patch('/incidentes/$id/cancelar');
  }
}