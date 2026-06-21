import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_routes.dart';
import '../../core/colores_app.dart';
import '../../data/models/incidente.dart';
import '../../data/services/api_exception.dart';
import '../../data/services/incidente_service.dart';
import '../viewmodels/sesion_viewmodel.dart';
import '../widgets/incidente_card.dart';

/// Home de Comando.
///
/// F.2 — Home views por rol + Detalle de Incidente.
///
/// ══════════════════════════════════════════════════════════════════════
/// LIMITACIÓN ESTRUCTURAL DEL BACKEND (descubierta en validación end-to-end,
/// no contemplada con suficiente alcance en el diagnóstico original / F.0.7)
/// ══════════════════════════════════════════════════════════════════════
///
/// El backend NO expone ningún endpoint que permita a COMANDO listar
/// incidentes pendientes de derivar. Se investigaron las alternativas:
///
/// - `GET /mis-incidentes`: filtra por `denuncianteId == actorId del JWT`.
///   El comandante no es un denunciante — siempre devuelve vacío.
/// - `GET /asignados`: filtra por `agenteId == actorId del JWT`.
///   El comandante no es un agente — siempre devuelve vacío.
/// - `GET /por-cai`: filtra por `unidadPolicialId == actorId del JWT`.
///   El comandante no es una unidad policial (CAI) — siempre devuelve
///   vacío, Y ADEMÁS un incidente recién creado (`CREADO`) NUNCA tiene
///   `unidadPolicialId` asignado todavía (ese es justamente el dato que
///   Comando debe asignar al derivar) — el endpoint es estructuralmente
///   incompatible con este caso de uso incluso si el actorId coincidiera.
///
/// Conclusión: no existe ningún workaround de solo-lectura que liste
/// "todos los incidentes CREADO" con los endpoints actuales. Como el
/// backend no se modifica en esta etapa, la solución es:
///
/// 1. Comunicar la limitación explícitamente en la UI (no simular datos
///    ni aparentar una lista vacía como si fuera "no hay incidentes").
/// 2. Ofrecer una vía funcional alternativa: localizar el incidente por
///    ID exacto (`GET /{id}`, sin restricción de rol) y operar sobre él
///    (derivar) desde ahí. El ID se comparte hoy por un canal externo
///    (ej. el Operador CAI o el propio Comando lo consulta directamente
///    en base de datos / logs) — no ideal, pero es lo único posible sin
///    tocar el backend.
///
/// FIX DE BACKEND PROPUESTO (documentado también en docs/deuda_backend.md):
/// `GET /incidentes?estado=CREADO` sin restricción de actor, accesible
/// solo a rol COMANDO — analógico a `/por-cai` pero sin filtrar por unidad.
class HomeComandoView extends StatefulWidget {
  const HomeComandoView({super.key});

  @override
  State<HomeComandoView> createState() => _HomeComandoViewState();
}

class _HomeComandoViewState extends State<HomeComandoView> {
  final _idController = TextEditingController();
  Incidente? _incidenteEncontrado;
  bool _buscando = false;
  String? _error;

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> _buscarPorId() async {
    final id = _idController.text.trim();
    if (id.isEmpty) return;

    setState(() {
      _buscando = true;
      _error = null;
      _incidenteEncontrado = null;
    });

    try {
      final incidente =
          await context.read<IIncidenteService>().consultar(id);
      if (mounted) setState(() => _incidenteEncontrado = incidente);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo buscar el incidente.');
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  Future<void> _derivar() async {
    if (_incidenteEncontrado == null) return;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _BottomSheetDerivar(incidente: _incidenteEncontrado!),
    );

    if (confirmed == true && mounted) {
      try {
        await context
            .read<IIncidenteService>()
            .derivar(_incidenteEncontrado!.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Incidente derivado al CAI más cercano.'),
              backgroundColor: Colors.green,
            ),
          );
          // Refrescar para reflejar el nuevo estado.
          _buscarPorId();
        }
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sesion = context.watch<SesionViewModel>();

    return Scaffold(
      backgroundColor: AppColors.blancoVerde,
      appBar: AppBar(
        backgroundColor: AppColors.negroTexto,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Centro de Comando',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Text(sesion.nombrePlaceholder,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await sesion.logout();
              if (mounted) {
                Navigator.pushReplacementNamed(
                    context, AppRoutes.roleSelection);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Aviso de limitación del backend ──────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade800),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'El backend actual no permite listar automáticamente '
                      'los incidentes pendientes de derivar. Busca el '
                      'incidente por su ID para gestionarlo.',
                      style: TextStyle(
                          color: Colors.amber.shade900, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Buscador por ID ────────────────────────────────────────
            const Text('Buscar incidente por ID',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _idController,
                    decoration: InputDecoration(
                      hintText: 'Ej: 5b1bc8de-6509-4ebe-bc9f-3dc407ca46d5',
                      hintStyle: const TextStyle(fontSize: 12),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    onSubmitted: (_) => _buscarPorId(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.negroTexto,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _buscando ? null : _buscarPorId,
                  child: _buscando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.search),
                ),
              ],
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(children: [
                  Icon(Icons.error_outline,
                      color: Colors.red.shade600, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!,
                        style: TextStyle(
                            color: Colors.red.shade700, fontSize: 13)),
                  ),
                ]),
              ),
            ],

            if (_incidenteEncontrado != null) ...[
              const SizedBox(height: 20),
              const Text('Incidente encontrado',
                  style:
                      TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 10),
              IncidenteCard(
                incidente: _incidenteEncontrado!,
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.detalleIncidente,
                  arguments: {'incidenteId': _incidenteEncontrado!.id},
                ),
                labelAccion: _incidenteEncontrado!.estado.name == 'CREADO'
                    ? 'Derivar a CAI'
                    : null,
                onAccion:
                    _incidenteEncontrado!.estado.name == 'CREADO'
                        ? _derivar
                        : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet de derivación a CAI (opción automática — F.0.7 gap 2).
class _BottomSheetDerivar extends StatelessWidget {
  final Incidente incidente;
  const _BottomSheetDerivar({required this.incidente});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.domain_add_outlined, size: 24),
            const SizedBox(width: 10),
            const Text('Derivar a CAI',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context, false)),
          ]),
          const SizedBox(height: 4),
          const Text(
            'El sistema derivará la emergencia al CAI más cercano usando la '
            'ubicación reportada.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade300),
            ),
            child: Row(children: [
              Icon(Icons.location_on, color: Colors.blue.shade700),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CAI más cercano (automático)',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(
                      'El sistema calcula el CAI con menor distancia al '
                      'punto de la emergencia (algoritmo Haversine).',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.check_circle, color: Colors.blue.shade600),
            ]),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.negroTexto,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar derivación',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}