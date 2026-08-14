import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:CallSos/core/app_routes.dart';
import 'package:CallSos/data/models/auth_result.dart';
import 'package:CallSos/data/models/enums/estado_incidente.dart';
import 'package:CallSos/data/models/enums/rol.dart';
import 'package:CallSos/data/models/enums/tipo_incidente_enum.dart';
import 'package:CallSos/data/models/incidente.dart';
import 'package:CallSos/data/services/auth_service.dart';
import 'package:CallSos/data/services/incidente_service.dart';
import 'package:CallSos/data/services/secure_storage.dart';
import 'package:CallSos/presentation/viewmodels/sesion_viewmodel.dart';
import 'package:CallSos/presentation/views/home_agente_view.dart';

/// Épica 5 (ruta técnica) — widget test de HomeAgenteView, la más simple
/// de las 4 "home" por rol (sin bottom sheet propio, a diferencia de
/// HomeDenuncianteView/HomeCAIView/HomeComandoView).
///
/// Cubre el contrato específico de esta vista (más allá de lo que ya
/// prueba IncidenteListViewModel por su cuenta, ver
/// incidente_list_viewmodel_test.dart): qué botón de acción corresponde a
/// cada EstadoIncidente, qué endpoint dispara cada uno, y el caso
/// documentado en el propio código como delicado — EN_ATENCION NO debe
/// llamar evaluar() (eso lo hace CrearReporteHallazgosService al enviar
/// el reporte; llamarlo aquí antes causaría 422 por incidente ya
/// FINALIZADO), sino navegar a ReporteHallazgosView.
class MockAuthService extends Mock implements IAuthService {}

class MockIncidenteService extends Mock implements IIncidenteService {}

class FakeSecureStorage implements ISecureStorage {
  final Map<String, String> _datos = {};
  @override
  Future<String?> read(String key) async => _datos[key];
  @override
  Future<void> write(String key, String value) async => _datos[key] = value;
  @override
  Future<void> delete(String key) async => _datos.remove(key);
}

Incidente _fake(String id, EstadoIncidente estado) => Incidente(
      id: id,
      fechaHora: DateTime(2026, 6, 14),
      tipo: TipoIncidenteEnum.ROBOS_O_ASALTOS,
      descripcion: 'desc',
      estado: estado,
      latitud: 10.391,
      longitud: -75.4794,
      denuncianteId: 'den-001',
    );

void main() {
  late MockAuthService authService;
  late MockIncidenteService incidenteService;
  late SesionViewModel sesion;

  setUp(() async {
    authService = MockAuthService();
    incidenteService = MockIncidenteService();
    sesion = SesionViewModel(authService: authService, storage: FakeSecureStorage());

    // Sesión ya autenticada como AGENTE — se hace vía login() real del VM
    // (no un setter directo, porque SesionViewModel no expone uno; es el
    // mismo patrón usado en login_view_test.dart/splash_view_test.dart).
    when(() => authService.login(username: 'ag-001', password: '1234')).thenAnswer(
      (_) async => const AuthResult(
          token: 'jwt-agente', actorId: 'ag-001', rol: Rol.AGENTE, nombre: 'Carlos Agente'),
    );
    await sesion.login(username: 'ag-001', password: '1234');
  });

  Widget appDePrueba() {
    return MultiProvider(
      providers: [
        Provider<IIncidenteService>.value(value: incidenteService),
        ChangeNotifierProvider<SesionViewModel>.value(value: sesion),
      ],
      child: MaterialApp(
        home: const HomeAgenteView(),
        routes: {
          AppRoutes.detalleIncidente: (_) => const Scaffold(body: Text('detalle_incidente')),
          AppRoutes.reporteHallazgos: (ctx) {
            final args = ModalRoute.of(ctx)!.settings.arguments as Map;
            return Scaffold(body: Text('reporte_hallazgos:${args['incidenteId']}'));
          },
          AppRoutes.roleSelection: (_) => const Scaffold(body: Text('role_selection')),
        },
      ),
    );
  }

  testWidgets('carga /asignados al iniciar y muestra el nombre del agente en el AppBar',
      (tester) async {
    when(() => incidenteService.asignados()).thenAnswer((_) async => []);

    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();

    verify(() => incidenteService.asignados()).called(1);
    expect(find.text('Mis asignaciones'), findsOneWidget);
    expect(find.text('Carlos Agente'), findsOneWidget);
  });

  testWidgets('lista vacía muestra el mensaje contextual del agente', (tester) async {
    when(() => incidenteService.asignados()).thenAnswer((_) async => []);

    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();

    expect(find.text('No tienes incidentes asignados.'), findsOneWidget);
  });

  testWidgets('AGENTE_ASIGNADO: botón "Ir en camino" llama enCamino() y refresca la lista',
      (tester) async {
    when(() => incidenteService.asignados()).thenAnswer(
        (_) async => [_fake('i-001', EstadoIncidente.AGENTE_ASIGNADO)]);
    when(() => incidenteService.enCamino('i-001')).thenAnswer((_) async {});

    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();

    expect(find.text('Ir en camino'), findsOneWidget);
    await tester.tap(find.text('Ir en camino'));
    await tester.pumpAndSettle();

    verify(() => incidenteService.enCamino('i-001')).called(1);
    // ejecutarTransicion refresca la lista tras la transición.
    verify(() => incidenteService.asignados()).called(2);
  });

  testWidgets('AGENTE_EN_CAMINO: botón "Llegué — Atender" llama atender()', (tester) async {
    when(() => incidenteService.asignados()).thenAnswer(
        (_) async => [_fake('i-002', EstadoIncidente.AGENTE_EN_CAMINO)]);
    when(() => incidenteService.atender('i-002')).thenAnswer((_) async {});

    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Llegué — Atender'));
    await tester.pumpAndSettle();

    verify(() => incidenteService.atender('i-002')).called(1);
  });

  testWidgets(
      'EN_ATENCION: botón "Finalizar y reportar" navega a ReporteHallazgosView '
      'con el incidenteId — NO llama evaluar() (evita el 422 documentado en el código)',
      (tester) async {
    when(() => incidenteService.asignados()).thenAnswer(
        (_) async => [_fake('i-003', EstadoIncidente.EN_ATENCION)]);

    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Finalizar y reportar'));
    await tester.pumpAndSettle();

    expect(find.text('reporte_hallazgos:i-003'), findsOneWidget);
    verifyNever(() => incidenteService.evaluar(any()));
  });

  testWidgets('estado sin acción para el agente (ej. FINALIZADO) no muestra botón',
      (tester) async {
    when(() => incidenteService.asignados()).thenAnswer(
        (_) async => [_fake('i-004', EstadoIncidente.FINALIZADO)]);

    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();

    // La card se renderiza (mock del ícono/tipo), pero sin ElevatedButton de acción.
    expect(find.byType(ElevatedButton), findsNothing);
  });

  testWidgets('tap en la card (fuera del botón) navega a DetalleIncidenteView', (tester) async {
    when(() => incidenteService.asignados()).thenAnswer(
        (_) async => [_fake('i-005', EstadoIncidente.AGENTE_ASIGNADO)]);

    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();

    // Toca el título del tipo de incidente (parte de la card, no el botón).
    await tester.tap(find.text('Robos o asaltos').hitTestable().first);
    await tester.pumpAndSettle();

    expect(find.text('detalle_incidente'), findsOneWidget);
  });

  testWidgets('botón de logout cierra sesión y navega a roleSelection', (tester) async {
    when(() => incidenteService.asignados()).thenAnswer((_) async => []);

    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();

    expect(sesion.isAuthenticated, isFalse);
    expect(find.text('role_selection'), findsOneWidget);
  });

  // Épica 8, Bloque 2, ítem 4 — al menos 1 test por IconButton crítico
  // que confirme que expone su nombre accesible a un lector de pantalla.
  testWidgets('el botón de logout expone tooltip "Cerrar sesión" (accesibilidad)',
      (tester) async {
    when(() => incidenteService.asignados()).thenAnswer((_) async => []);

    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();

    expect(find.byTooltip('Cerrar sesión'), findsOneWidget);
  });
}