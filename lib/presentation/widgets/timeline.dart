import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/colores_app.dart';
import '../../data/models/auditoria_incidente.dart';
import '../../data/models/enums/rol.dart';
import '../../data/services/api_exception.dart';
import '../../data/services/auditoria_service.dart';
import 'empty_state.dart';
import 'error_view.dart';
import 'estado_chip.dart';
import 'loading_view.dart';

/// Línea de tiempo del historial de auditoría de un incidente —
/// EPIC-07 (Auditorías e historiales).
///
/// Autocontenido: llama `GET /auditoria/incidente/{id}`
/// ([IAuditoriaService.historial]) por su cuenta y gestiona sus propios
/// estados de carga/vacío/error (mismo patrón que [EtaWidget]), así que
/// puede insertarse en cualquier vista (hoy `DetalleIncidenteView`, tab
/// "Historial") pasándole solo el [incidenteId].
///
/// Solo lectura — no dispara ninguna acción, solo muestra lo que el
/// backend ya autorizó para el actor de la sesión (`AuditoriaController`
/// filtra por rol antes de responder; este widget no necesita saber
/// nada de esa lógica, solo mostrar lo que llega o el 403 si el backend
/// lo rechaza).
class Timeline extends StatefulWidget {
  final String incidenteId;

  const Timeline({required this.incidenteId, super.key});

  @override
  State<Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<Timeline> {
  List<AuditoriaIncidente>? _eventos;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final eventos =
          await context.read<IAuditoriaService>().historial(widget.incidenteId);
      if (mounted) setState(() => _eventos = eventos);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo cargar el historial.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingView(mensaje: 'Cargando historial...');
    }

    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _cargar);
    }

    final eventos = _eventos ?? const [];
    if (eventos.isEmpty) {
      return const EmptyState(
        icon: Icons.history_toggle_off,
        message: 'Todavía no hay eventos registrados.',
        subtitle: 'Acá aparecerá el historial a medida que ocurran cambios.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: eventos.length,
      itemBuilder: (context, index) {
        final esUltimo = index == eventos.length - 1;
        return _TimelineTile(evento: eventos[index], esUltimo: esUltimo);
      },
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final AuditoriaIncidente evento;
  final bool esUltimo;

  const _TimelineTile({required this.evento, required this.esUltimo});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Riel (punto + línea conectora) ────────────────────────
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.only(top: 3),
                decoration: const BoxDecoration(
                  color: AppColors.verdeOscuro,
                  shape: BoxShape.circle,
                ),
              ),
              if (!esUltimo)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.grey.shade300,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),

          // ── Contenido ──────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: esUltimo ? 0 : 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _fecha(evento.timestamp),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      _badge(),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _actorLabel(evento.actorRol),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.negroTexto,
                    ),
                  ),
                  if (evento.detalle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      evento.detalle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                  if (evento.esCambioGenerico) ...[
                    const SizedBox(height: 6),
                    _cambioGenericoChip(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Badge de estado: para una transición real, el chip de estado
  /// (ver [EstadoChip]) es la representación más clara. Para un cambio
  /// de campo genérico, [estadoNuevo] no representa una transición (es
  /// solo el estado vigente al momento del evento — ver docstring de
  /// [AuditoriaIncidente]), así que ahí no se muestra badge de estado
  /// (el chip de campo cambiado, más abajo, ya cuenta la historia).
  Widget _badge() {
    if (evento.esCambioGenerico) return const SizedBox();
    return EstadoChip(estado: evento.estadoNuevo, compact: true);
  }

  Widget _cambioGenericoChip() {
    final campo = evento.campo ?? '';
    final anterior = evento.valorAnteriorGenerico ?? '—';
    final nuevo = evento.valorNuevoGenerico ?? '—';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.deepPurple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.25)),
      ),
      child: Text(
        '$campo: $anterior → $nuevo',
        style: TextStyle(
          fontSize: 12,
          color: Colors.deepPurple.shade700,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Etiqueta legible del actor. `actorRol` viaja como el `.name` exacto
  /// de `RolUsuario` (mismo contrato que el resto de la app — ver
  /// `rol.dart`), así que se reutiliza [RolDisplay.etiqueta] cuando el
  /// valor es reconocido; si llegara un rol desconocido (desalineación
  /// futura backend/frontend) se muestra tal cual llegó en vez de
  /// tumbar el widget.
  String _actorLabel(String actorRolRaw) {
    try {
      final rol = rolFromJson(actorRolRaw);
      return '${rol.etiqueta} · ${evento.actorId}';
    } on FormatException {
      return '$actorRolRaw · ${evento.actorId}';
    }
  }

  String _fecha(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/${dt.year}  $h:$min';
  }
}