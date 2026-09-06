import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_radius.dart';
import '../../core/app_routes.dart';
import '../../core/app_spacing.dart';
import '../../core/app_text_styles.dart';
import '../../core/colores_app.dart';
import '../../data/models/enums/estado_incidente.dart';
import '../../data/models/enums/rol.dart';
import '../../data/models/incidente.dart';
import '../../data/models/invitacion_agente.dart';
import '../../data/services/api_exception.dart';
import '../../data/services/cai_service.dart';
import '../../data/services/incidente_service.dart';
import '../viewmodels/incidente_list_viewmodel.dart';
import '../viewmodels/sesion_viewmodel.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/incidente_card.dart';
import '../widgets/role_header.dart';
import '../widgets/incidente_list_body.dart';

/// Home de Comando.
///
/// F.2 + FIX (endpoint Gap 2 resuelto en validación end-to-end):
/// Usa el nuevo endpoint `GET /incidentes/por-estado?estado=CREADO`
/// que lista todos los incidentes pendientes de derivar sin filtrar
/// por actorId — el único endpoint que tiene sentido para COMANDO.
///
/// Tabs: "Reportados" (CREADO, [_vm]) / "Delegados" (historial completo
/// de derivaciones, [_vmDelegados] — EPIC-18).
///
/// EPIC-12 (Design System, auditoría UX/UI) — "Experiencia del
/// Comandante": "Reportados" ya hereda el Design System de EPIC-09/
/// EPIC-11 a través de [IncidenteCard]/[IncidenteListBody] (componentes
/// compartidos); acá se migran además el sheet de derivación
/// ([_BottomSheetDerivar]) a los tokens de EPIC-01
/// (`AppSpacing`/`AppRadius`/`AppTextStyles`), por consistencia. En esa
/// épica, "Delegados" todavía no tenía de dónde traer datos reales
/// (hallazgo #14) — mostraba [_avisoDelegadosPendiente], un panel
/// honesto sobre la limitación en vez de disfrazarla de lista vacía.
///
/// EPIC-18 (backend + frontend) — resuelve el hallazgo #14: nuevo
/// endpoint `GET /incidentes/derivados` (ver
/// `IIncidenteService.derivados()`), con su propio
/// [IncidenteListViewModel] independiente de [_vm] — son dos listas
/// con datos y ciclo de vida completamente distintos (una se recarga
/// tras derivar un incidente, la otra no), así que comparten
/// [IncidenteListBody]/[IncidenteCard] pero NO el mismo ViewModel.
/// [_avisoDelegadosPendiente] y su comentario de clase se retiran junto
/// con esta épica — quedan solo en el historial de git para quien
/// busque el porqué de una decisión anterior.
class HomeComandoView extends StatefulWidget {
  const HomeComandoView({super.key});

  @override
  State<HomeComandoView> createState() => _HomeComandoViewState();
}

class _HomeComandoViewState extends State<HomeComandoView>
    with SingleTickerProviderStateMixin {
  late IncidenteListViewModel _vm;
  late IncidenteListViewModel _vmDelegados;
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    final service = context.read<IIncidenteService>();
    _vm = IncidenteListViewModel(
      service: service,
      // FIX: usar el nuevo endpoint por-estado en vez de porCai()
      // que era estructuralmente incompatible con el rol COMANDO.
      fetchFn: () => service.porEstado(EstadoIncidente.CREADO),
    );
    _vm.cargar();

    // EPIC-18 — ViewModel independiente para "Delegados": misma clase
    // (mismo checklist de loading/error/empty, mismo skeleton — EPIC-09/
    // EPIC-15), pero una instancia propia, porque es una lista distinta
    // con su propio ciclo de carga.
    _vmDelegados = IncidenteListViewModel(
      service: service,
      fetchFn: () => service.derivados(),
    );
    _vmDelegados.cargar();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _vm.dispose();
    _vmDelegados.dispose();
    super.dispose();
  }

  /// Diálogo para generar un token de invitación de agente.
  ///
  /// LIMITACIÓN CONOCIDA: no hay endpoint de "listar CAIs" en el backend
  /// todavía (deuda_backend.md no lo contemplaba), así que Comando escribe
  /// el ID del CAI a mano en vez de elegirlo de un selector. Si se agrega
  /// ese endpoint más adelante, reemplazar este TextField por un
  /// DropdownButton poblado desde él.
  Future<void> _mostrarGenerarInvitacion(BuildContext context) async {
    final caiService = context.read<ICaiService>();
    final caiIdController = TextEditingController();
    InvitacionAgente? invitacionGenerada;
    String? error;
    bool cargando = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Generar invitación de agente'),
          // Bloque 4 (Épica 8) — AlertDialog no hace scroll de su content
          // por defecto. El error de ApiException puede ser un mensaje
          // largo (ver ApiException.message, sin límite de longitud del
          // backend); sin este SingleChildScrollView, un mensaje largo en
          // una pantalla chica podría desbordar el diálogo.
          content: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (invitacionGenerada == null) ...[
                const Text(
                  'Escribe el ID del CAI al que quedará asignado el '
                  'agente. El token dura 48 horas y es de un solo uso.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: caiIdController,
                  decoration: const InputDecoration(
                    labelText: 'ID del CAI',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!, style: const TextStyle(color: Colors.red)),
                ],
              ] else ...[
                const Text('Comparte este token con el agente '
                    '(verbalmente o por un canal interno):'),
                const SizedBox(height: 12),
                SelectableText(
                  invitacionGenerada!.token,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text(
                  'Expira: ${invitacionGenerada!.fechaExpiracion}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(invitacionGenerada == null ? 'Cancelar' : 'Cerrar'),
            ),
            if (invitacionGenerada == null)
              ElevatedButton(
                onPressed: cargando
                    ? null
                    : () async {
                        if (caiIdController.text.trim().isEmpty) return;
                        setDialogState(() {
                          cargando = true;
                          error = null;
                        });
                        try {
                          final invitacion = await caiService
                              .generarInvitacion(caiIdController.text.trim());
                          setDialogState(() {
                            invitacionGenerada = invitacion;
                            cargando = false;
                          });
                        } on ApiException catch (e) {
                          setDialogState(() {
                            error = e.message;
                            cargando = false;
                          });
                        }
                      },
                child: cargando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Generar'),
              ),
          ],
        ),
      ),
    );

    caiIdController.dispose();
  }

  Future<void> _mostrarDerivacion(
      BuildContext context, Incidente incidente) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      // Bloque 4 (Épica 8) — mismo fix que ya se aplicó en
      // HomeCAIView/HomeDenuncianteView: sin isScrollControlled: true,
      // el sheet queda limitado a una fracción fija de la pantalla y su
      // contenido (sin SingleChildScrollView) puede desbordar en
      // pantallas chicas. Por consistencia con los otros 2 sheets del
      // proyecto, se aplica aquí también aunque el contenido actual sea
      // corto y estático.
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _BottomSheetDerivar(incidente: incidente),
    );

    if (confirmed == true && context.mounted) {
      final ok = await _vm.ejecutarTransicion(
        incidenteId: incidente.id,
        accion: () =>
            context.read<IIncidenteService>().derivar(incidente.id),
      );
      if (ok && context.mounted) {
        AppSnackBar.exito(context, 'Incidente derivado al CAI más cercano.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sesion = context.watch<SesionViewModel>();

    return ChangeNotifierProvider.value(
      value: _vm,
      child: Scaffold(
        backgroundColor: AppColors.blancoVerde,
        appBar: RoleHeader(
          rol: Rol.COMANDO,
          titulo: 'Centro de Comando',
          subtitulo: sesion.nombreMostrar,
          extraActions: [
            IconButton(
              icon: const Icon(Icons.vpn_key_outlined, color: Colors.white),
              tooltip: 'Generar invitación de agente',
              onPressed: () => _mostrarGenerarInvitacion(context),
            ),
          ],
          bottom: TabBar(
            controller: _tabs,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: const [
              Tab(text: 'Reportados'),
              Tab(text: 'Delegados'),
            ],
          ),
        ),
        body: Consumer<IncidenteListViewModel>(
          builder: (ctx, vm, _) => TabBarView(
            controller: _tabs,
            children: [
              // Tab 1 — Reportados (CREADO): listado automático real
              IncidenteListBody(
                vm: vm,
                incidentes: vm.incidentes,
                mensajeVacio: 'No hay emergencias pendientes de derivar.',
                iconoVacio: Icons.inbox_outlined,
                buildCard: (i) => IncidenteCard(
                  incidente: i,
                  onTap: () => Navigator.pushNamed(ctx,
                      AppRoutes.detalleIncidente,
                      arguments: {'incidenteId': i.id}),
                  labelAccion:
                      vm.enProceso(i.id) ? 'Derivando...' : 'Derivar a CAI',
                  onAccion: vm.enProceso(i.id)
                      ? null
                      : () => _mostrarDerivacion(ctx, i),
                ),
              ),

              // Tab 2 — Delegados: historial real de derivaciones
              // (EPIC-18) — ViewModel propio ([_vmDelegados]), NO el
              // mismo `vm` del builder de arriba (ese es [_vm], de
              // "Reportados"). `ListenableBuilder` en vez de otro
              // `Consumer` porque [_vmDelegados] no está en el árbol de
              // Provider (solo [_vm] lo está, vía el
              // `ChangeNotifierProvider.value` de más abajo) — dos
              // ChangeNotifierProvider del mismo tipo en el mismo árbol
              // se pisarían entre sí por tipo, así que este tab escucha
              // su propio ViewModel directamente.
              ListenableBuilder(
                listenable: _vmDelegados,
                builder: (ctx, _) => IncidenteListBody(
                  vm: _vmDelegados,
                  incidentes: _vmDelegados.incidentes,
                  mensajeVacio: 'Todavía no se derivó ningún incidente.',
                  iconoVacio: Icons.history,
                  buildCard: (i) => IncidenteCard(
                    incidente: i,
                    onTap: () => Navigator.pushNamed(
                      ctx,
                      AppRoutes.detalleIncidente,
                      arguments: {'incidenteId': i.id},
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomSheetDerivar extends StatelessWidget {
  final Incidente incidente;
  const _BottomSheetDerivar({required this.incidente});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.xl, AppSpacing.xl, 32),
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.domain_add_outlined, size: 24),
            AppSpacing.gapSm,
            const Text('Derivar a CAI', style: AppTextStyles.tituloMediano),
            const Spacer(),
            IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cerrar',
                onPressed: () => Navigator.pop(context, false)),
          ]),
          AppSpacing.gapXs,
          Text(
            'El sistema derivará la emergencia al CAI más cercano '
            'usando la ubicación reportada (algoritmo Haversine).',
            style: AppTextStyles.cuerpoPequeno
                .copyWith(color: Colors.grey.shade600),
          ),
          AppSpacing.gapLg,
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.08),
              borderRadius: AppRadius.borderSm,
              border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.location_on, color: AppColors.info),
              AppSpacing.gapMd,
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CAI más cercano (automático)',
                        style: AppTextStyles.cuerpo),
                    Text(
                      'El sistema calcula el CAI con menor distancia al '
                      'punto de la emergencia.',
                      style: AppTextStyles.etiqueta,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.check_circle, color: AppColors.info),
            ]),
          ),
          AppSpacing.gapXxl,
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.negroTexto,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar derivación',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
        ),
      ),
    );
  }
}