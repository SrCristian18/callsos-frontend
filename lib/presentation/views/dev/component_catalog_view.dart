import 'package:flutter/material.dart';

import '../../../core/colores_app.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_password_field.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/confirmation_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_view.dart';

/// Catálogo visual de los componentes base — EPIC-03 (Design System,
/// auditoría UX/UI).
///
/// Solo para validación manual durante desarrollo — "criterio de
/// terminado" de la épica pide poder ver cada componente en todos sus
/// estados ANTES de conectarlos a ninguna vista real (EPIC-04). No es
/// parte del flujo de navegación normal de la app: no aparece en
/// [AppRoutes] salvo detrás de `kDebugMode` (ver `app_routes.dart`),
/// así que nunca es alcanzable en un build de release.
///
/// Equivalente casero a un Storybook: una sola pantalla, scrolleable,
/// con secciones por componente.
class ComponentCatalogView extends StatefulWidget {
  const ComponentCatalogView({super.key});

  @override
  State<ComponentCatalogView> createState() => _ComponentCatalogViewState();
}

class _ComponentCatalogViewState extends State<ComponentCatalogView> {
  bool _loadingDemo = false;
  final _campoConError = TextEditingController();

  @override
  void dispose() {
    _campoConError.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blancoVerde,
      appBar: AppBar(
        backgroundColor: AppColors.verdeOscuro,
        title: const Text('Catálogo de componentes',
            style: TextStyle(color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _seccion('AppButton — variantes', [
            AppButton(label: 'Primary', variant: AppButtonVariant.primary, onPressed: () {}),
            const SizedBox(height: 10),
            AppButton(label: 'Secondary', variant: AppButtonVariant.secondary, onPressed: () {}),
            const SizedBox(height: 10),
            AppButton(label: 'Danger', variant: AppButtonVariant.danger, onPressed: () {}),
            const SizedBox(height: 10),
            AppButton(label: 'Outlined', variant: AppButtonVariant.outlined, onPressed: () {}),
          ]),
          _seccion('AppButton — con ícono', [
            AppButton(label: 'Reintentar', icon: Icons.refresh, onPressed: () {}),
          ]),
          _seccion('AppButton — estados', [
            const Text('Deshabilitado (onPressed: null):',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 6),
            const AppButton(label: 'No disponible', onPressed: null),
            const SizedBox(height: 16),
            Text(
              _loadingDemo
                  ? 'Cargando — tocá para volver al estado normal:'
                  : 'Tocá para ver el estado de carga (sin salto de tamaño):',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 6),
            AppButton(
              label: 'Enviar',
              isLoading: _loadingDemo,
              onPressed: () => setState(() => _loadingDemo = !_loadingDemo),
            ),
          ]),
          _seccion('AppButton — ancho de contenido (fullWidth: false)', [
            Row(
              children: [
                AppButton(
                  label: 'Chico',
                  fullWidth: false,
                  variant: AppButtonVariant.outlined,
                  onPressed: () {},
                ),
              ],
            ),
          ]),
          _seccion('AppTextField', const [
            AppTextField(hintText: 'Correo electrónico', icon: Icons.email_outlined),
          ]),
          _seccion('AppTextField — con error', [
            AppTextField(
              controller: _campoConError,
              hintText: 'Nombre completo',
              icon: Icons.person_outline,
              errorText: 'Este campo es obligatorio',
            ),
          ]),
          _seccion('AppTextField — deshabilitado', const [
            AppTextField(
              hintText: 'No editable',
              icon: Icons.lock_clock_outlined,
              enabled: false,
            ),
          ]),
          _seccion('AppPasswordField — el ícono de ojo SÍ funciona acá', [
            AppPasswordField(hintText: 'Contraseña'),
          ]),
          _seccion('AppPasswordField — con error', [
            AppPasswordField(
              hintText: 'Contraseña',
              errorText: 'Mínimo 6 caracteres',
            ),
          ]),
          _seccion('ConfirmationDialog', [
            AppButton(
              label: 'Abrir confirmación normal',
              variant: AppButtonVariant.outlined,
              onPressed: () async {
                final ok = await ConfirmationDialog.show(
                  context,
                  title: '¿Continuar?',
                  message: 'Esta es una confirmación de ejemplo, sin riesgo.',
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Resultado: $ok')),
                  );
                }
              },
            ),
            const SizedBox(height: 10),
            AppButton(
              label: 'Abrir confirmación peligrosa',
              variant: AppButtonVariant.danger,
              onPressed: () async {
                final ok = await ConfirmationDialog.show(
                  context,
                  title: '¿Eliminar todo?',
                  message: 'Esta acción no se puede deshacer.',
                  confirmText: 'Sí, eliminar',
                  isDangerous: true,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Resultado: $ok')),
                  );
                }
              },
            ),
          ]),
          _seccion('LoadingView', const [
            SizedBox(height: 120, child: LoadingView()),
            SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: LoadingView(mensaje: 'Cargando incidente...'),
            ),
          ]),
          _seccion('ErrorView', [
            SizedBox(
              height: 220,
              child: ErrorView(
                message: 'No se pudo conectar al servidor.',
                onRetry: () {},
              ),
            ),
            const SizedBox(height: 12),
            const SizedBox(
              height: 160,
              child: ErrorView(
                message: 'Error sin acción disponible.',
                icon: Icons.error_outline,
              ),
            ),
          ]),
          _seccion('EmptyState', const [
            SizedBox(
              height: 220,
              child: EmptyState(
                icon: Icons.inbox_outlined,
                message: 'No hay incidentes disponibles.',
                subtitle: 'Los que reportes van a aparecer acá.',
              ),
            ),
          ]),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _seccion(String titulo, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.negroTexto),
          ),
          const Divider(),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}