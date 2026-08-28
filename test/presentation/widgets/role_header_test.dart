import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker, TickerCallback;
import 'package:flutter_test/flutter_test.dart';

import 'package:CallSos/core/colores_app.dart';
import 'package:CallSos/data/models/enums/rol.dart';
import 'package:CallSos/presentation/widgets/logout_button.dart';
import 'package:CallSos/presentation/widgets/role_header.dart';

void main() {
  Widget envolver(PreferredSizeWidget appBar, {Widget body = const SizedBox()}) =>
      MaterialApp(home: Scaffold(appBar: appBar, body: body));

  Color colorDe(WidgetTester tester) =>
      tester.widget<AppBar>(find.byType(AppBar)).backgroundColor!;

  group('RoleHeader — criterio de terminado: 4 colores distintos entre sí (fix hallazgo #6)', () {
    testWidgets('DENUNCIANTE usa AppColors.acentoDenunciante', (tester) async {
      await tester.pumpWidget(envolver(const RoleHeader(
        rol: Rol.DENUNCIANTE, titulo: 'CallSOS', subtitulo: 'Ana',
      )));
      expect(colorDe(tester), AppColors.acentoDenunciante);
    });

    testWidgets('AGENTE usa AppColors.acentoAgente', (tester) async {
      await tester.pumpWidget(envolver(const RoleHeader(
        rol: Rol.AGENTE, titulo: 'Mis asignaciones', subtitulo: 'Pedro',
      )));
      expect(colorDe(tester), AppColors.acentoAgente);
    });

    testWidgets('OPERADOR_CAI usa AppColors.acentoOperadorCai (ya NO Colors.green.shade700)',
        (tester) async {
      await tester.pumpWidget(envolver(const RoleHeader(
        rol: Rol.OPERADOR_CAI, titulo: 'Panel CAI', subtitulo: 'CAI Centro',
      )));
      final color = colorDe(tester);
      expect(color, AppColors.acentoOperadorCai);
      // Antes del fix, este AppBar usaba Colors.green.shade700 (0xFF388E3C)
      // escrito a mano, sin pasar por AppColors — confirmamos que ya no.
      expect(color, isNot(Colors.green.shade700));
    });

    testWidgets('COMANDO usa AppColors.acentoComando (ya NO el mismo color que AGENTE)',
        (tester) async {
      await tester.pumpWidget(envolver(const RoleHeader(
        rol: Rol.COMANDO, titulo: 'Centro de Comando', subtitulo: 'Comando Central',
      )));
      expect(colorDe(tester), AppColors.acentoComando);
    });

    test('los 4 colores de acento son pairwise distintos entre sí — '
        'la aserción central del hallazgo #6', () {
      final colores = {
        AppColors.acentoDenunciante,
        AppColors.acentoAgente,
        AppColors.acentoOperadorCai,
        AppColors.acentoComando,
      };
      // Si dos roles compartieran color (como Agente/Comando antes del
      // fix), el Set colapsaría a menos de 4 elementos.
      expect(colores.length, 4);
    });
  });

  group('RoleHeader — contenido', () {
    testWidgets('muestra título y subtítulo', (tester) async {
      await tester.pumpWidget(envolver(const RoleHeader(
        rol: Rol.DENUNCIANTE, titulo: 'CallSOS', subtitulo: 'Ana Pérez',
      )));

      expect(find.text('CallSOS'), findsOneWidget);
      expect(find.text('Ana Pérez'), findsOneWidget);
    });
  });

  group('RoleHeader — logout incluido (EPIC-04)', () {
    testWidgets('siempre incluye LogoutButton, sin que la vista lo agregue',
        (tester) async {
      await tester.pumpWidget(envolver(const RoleHeader(
        rol: Rol.AGENTE, titulo: 'X', subtitulo: 'Y',
      )));

      expect(find.byType(LogoutButton), findsOneWidget);
    });

    testWidgets('extraActions se muestran ANTES del LogoutButton', (tester) async {
      await tester.pumpWidget(envolver(RoleHeader(
        rol: Rol.COMANDO,
        titulo: 'Centro de Comando',
        subtitulo: 'X',
        extraActions: [
          IconButton(
            icon: const Icon(Icons.vpn_key_outlined),
            tooltip: 'Generar invitación',
            onPressed: () {},
          ),
        ],
      )));

      final acciones = tester
          .widget<AppBar>(find.byType(AppBar))
          .actions!;
      expect(acciones.length, 2);
      expect(acciones.last, isA<LogoutButton>());
    });

    testWidgets('sin extraActions, la única acción es LogoutButton', (tester) async {
      await tester.pumpWidget(envolver(const RoleHeader(
        rol: Rol.DENUNCIANTE, titulo: 'X', subtitulo: 'Y',
      )));

      final acciones = tester.widget<AppBar>(find.byType(AppBar)).actions!;
      expect(acciones.length, 1);
      expect(acciones.single, isA<LogoutButton>());
    });
  });

  group('RoleHeader — bottom (TabBar) y preferredSize', () {
    testWidgets('sin bottom, preferredSize es solo kToolbarHeight', (tester) async {
      const header = RoleHeader(rol: Rol.DENUNCIANTE, titulo: 'X', subtitulo: 'Y');
      expect(header.preferredSize.height, kToolbarHeight);
    });

    testWidgets('con bottom, preferredSize suma el alto del TabBar', (tester) async {
      final tabController = TabController(length: 2, vsync: const _NoVsync());
      final tabBar = TabBar(controller: tabController, tabs: const [
        Tab(text: 'A'),
        Tab(text: 'B'),
      ]);
      final header = RoleHeader(
        rol: Rol.OPERADOR_CAI,
        titulo: 'Panel CAI',
        subtitulo: 'X',
        bottom: tabBar,
      );

      expect(
        header.preferredSize.height,
        kToolbarHeight + tabBar.preferredSize.height,
      );
    });

    testWidgets('el TabBar pasado en bottom se renderiza', (tester) async {
      final tabController = TabController(length: 2, vsync: const TestVSync());
      await tester.pumpWidget(envolver(
        RoleHeader(
          rol: Rol.OPERADOR_CAI,
          titulo: 'Panel CAI',
          subtitulo: 'X',
          bottom: TabBar(controller: tabController, tabs: const [
            Tab(text: 'Por Asignar'),
            Tab(text: 'Historial'),
          ]),
        ),
        body: TabBarView(controller: tabController, children: const [
          SizedBox(),
          SizedBox(),
        ]),
      ));

      expect(find.text('Por Asignar'), findsOneWidget);
      expect(find.text('Historial'), findsOneWidget);
    });
  });
}

/// TickerProvider no-op — solo para construir un TabController fuera de
/// un widget con SingleTickerProviderStateMixin, en el test de
/// preferredSize que no llega a hacer pump() real.
class _NoVsync implements TickerProvider {
  const _NoVsync();
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}