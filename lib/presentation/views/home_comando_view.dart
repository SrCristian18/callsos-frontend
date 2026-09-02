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
/// Tabs: "Reportados" (CREADO) / "Delegados" (resto).
///
/// EPIC-12 (Design System, auditoría UX/UI) — "Experiencia del
/// Comandante":
/// - "Reportados" ya hereda el Design System de EPIC-09/EPIC-11 a
///   través de [IncidenteCard]/[IncidenteListBody] (componentes
///   compartidos); acá se migran además el sheet de derivación
///   ([_BottomSheetDerivar]) a los tokens de EPIC-01
///   (`AppSpacing`/`AppRadius`/`AppTextStyles`), por consistencia.
/// - "Delegados" reemplaza el aviso plano de antes por un panel
///   claramente marcado como "función pendiente de backend" (ver
///   [_avisoDelegadosPendiente]) — heurística #1 (visibilidad del
///   estado del sistema): un tab vacío se confunde con "no hay datos
///   todavía"; este panel dice explícitamente que la función no está
///   construida y por qué, en vez de disfrazarla de lista vacía.
///
/// REQUIERE CAMBIO DE BACKEND (hallazgo #14, fuera de alcance de esta
/// épica): el historial completo de derivaciones de Comando necesita
/// un endpoint nuevo — hoy `porEstado(CREADO)` solo trae lo pendiente
/// de derivar; una vez derivado, el incidente desaparece de lo que
/// Comando puede consultar. Esta épica NO intenta resolver eso — solo
/// comunica la limitación con más claridad mientras se resuelve.
class HomeComandoView extends StatefulWidget {
  const HomeComandoView({super.key});

  @override
  State<HomeComandoView> createState() => _HomeComandoViewState();
}

class _HomeComandoViewState extends State<HomeComandoView>
    with SingleTickerProviderStateMixin {
  late IncidenteListViewModel _vm;
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
  }

  @override
  void dispose() {
    _tabs.dispose();
    _vm.dispose();
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

              // Tab 2 — Delegados: recarga mismos datos filtrados por estado
              // (los ya derivados no aparecen en el fetchFn de CREADO,
              // por eso usamos incidentesPorEstado para mostrar el historial
              // dentro de los datos ya cargados — que incluye solo CREADO.
              // Para un historial real de Comando se necesitaría otro endpoint.
              // EPIC-12: ver [_avisoDelegadosPendiente] — mismo hueco de
              // backend, presentación mejorada.)
              _avisoDelegadosPendiente(),
            ],
          ),
        ),
      ),
    );
  }

  /// EPIC-12 — panel de "Delegados", honesto sobre por qué está vacío.
  ///
  /// REQUIERE CAMBIO DE BACKEND (hallazgo #14): esto NO es una lista
  /// vacía en el sentido normal ("todavía no hay datos, pero la
  /// función funciona") — es una función que directamente no se puede
  /// construir todavía del lado del cliente, porque el backend no
  /// expone el endpoint que la alimentaría. Por eso NO usa
  /// [EmptyState] (ese widget comunica "sin datos", no "sin función")
  /// y en cambio usa un panel con estilo `AppColors.info` — visualmente
  /// distinto tanto de un estado vacío normal como de un error real.
  ///
  /// La sugerencia práctica ("mirá el detalle antes de derivar") es la
  /// MISMA limitación de siempre, solo mejor explicada: `porEstado`
  /// solo trae `CREADO`, así que en cuanto Comando deriva un incidente,
  /// deja de poder consultarlo desde acá — no hay ningún atajo nuevo,
  /// solo comunicación más clara de uno ya existente.
  Widget _avisoDelegadosPendiente() {
    // FIX: en pantallas de test/dispositivos con poca altura disponible
    // (el TabBarView le da a este tab una altura FIJA, no scrolleable
    // por sí sola), este panel —bastante más alto que el aviso plano
    // que reemplaza— podía desbordar verticalmente ("RenderFlex
    // overflowed... bottom"). `SingleChildScrollView` es la misma
    // salvaguarda que ya usan los demás sheets/paneles de esta vista
    // (`_BottomSheetDerivar`, el diálogo de invitación) — si el
    // contenido entra, se ve idéntico (`Center` sigue centrándolo
    // cuando sobra espacio); si no entra, scrollea en vez de desbordar.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.08),
              borderRadius: AppRadius.borderLg,
              border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: const BoxDecoration(
                    color: AppColors.info,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.construction_outlined,
                      color: Colors.white, size: 26),
                ),
                AppSpacing.gapMd,
                Text(
                  'Historial de derivaciones — pendiente de backend',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.tituloMediano,
                ),
                AppSpacing.gapSm,
                Text(
                  'Esta pestaña va a mostrar el historial completo de '
                  'incidentes ya derivados. Todavía no está disponible: '
                  'requiere un endpoint adicional en el backend que hoy '
                  'no existe (hallazgo #14 de la auditoría UX/UI).',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.cuerpoPequeno
                      .copyWith(color: Colors.grey.shade700),
                ),
                AppSpacing.gapMd,
                Divider(color: AppColors.info.withValues(alpha: 0.25)),
                AppSpacing.gapSm,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        size: 16, color: AppColors.info),
                    AppSpacing.gapSm,
                    Expanded(
                      child: Text(
                        'Mientras tanto: abrí el detalle de un incidente, '
                        'en "Reportados", ANTES de derivarlo — ahí vas a '
                        'poder seguir su estado y su historial de '
                        'auditoría aunque ya no aparezca en esta lista.',
                        textAlign: TextAlign.start,
                        style: AppTextStyles.etiqueta.copyWith(
                          color: AppColors.info,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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