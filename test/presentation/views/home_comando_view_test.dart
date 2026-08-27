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
import 'package:CallSos/data/models/invitacion_agente.dart';
import 'package:CallSos/data/services/api_exception.dart';
import 'package:CallSos/data/services/auth_service.dart';
import 'package:CallSos/data/services/cai_service.dart';
import 'package:CallSos/data/services/incidente_service.dart';
import 'package:CallSos/data/services/secure_storage.dart';
import 'package:CallSos/presentation/viewmodels/sesion_viewmodel.dart';
import 'package:CallSos/presentation/views/home_comando_view.dart';

/// Épica 5 (ruta técnica) — widget test de HomeComandoView.
///
/// Particularidades frente a las otras "home": usa `porEstado(CREADO)`
/// en vez de un endpoint por-actor (fetchFn distinto), el tab
/// "Delegados" es un aviso estático (limitación documentada: no hay
/// endpoint de historial para Comando todavía — no hay nada que probar
/// ahí más allá de que el texto exista), y el ícono de llave abre un
/// diálogo para generar invitaciones de agente (ICaiService
/// .generarInvitacion) — flujo exclusivo de este rol.
class MockAuthService extends Mock implements IAuthService {}

class MockIncidenteService extends Mock implements IIncidenteService {}

class MockCaiService extends Mock implements ICaiService {}

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
  late MockCaiService caiService;
  late SesionViewModel sesion;

  setUp(() async {
    authService = MockAuthService();
    incidenteService = MockIncidenteService();
    caiService = MockCaiService();
    sesion = SesionViewModel(authService: authService, storage: FakeSecureStorage());

    when(() => authService.login(username: 'com-001', password: '1234')).thenAnswer(
      (_) async => const AuthResult(
          token: 'jwt-comando', actorId: 'com-001', rol: Rol.COMANDO, nombre: 'Comando Central'),
    );
    await sesion.login(username: 'com-001', password: '1234');
  });

  Widget appDePrueba() {
    return MultiProvider(
      providers: [
        Provider<IIncidenteService>.value(value: incidenteService),
        Provider<ICaiService>.value(value: caiService),
        ChangeNotifierProvider<SesionViewModel>.value(value: sesion),
      ],
      child: MaterialApp(
        home: const HomeComandoView(),
        routes: {
          AppRoutes.detalleIncidente: (_) => const Scaffold(body: Text('detalle_incidente')),
          AppRoutes.roleSelection: (_) => const Scaffold(body: Text('role_selection')),
        },
      ),
    );
  }

  testWidgets(
      'carga /incidentes/por-estado?estado=CREADO al iniciar y muestra '
      '"Centro de Comando" + nombre', (tester) async {
    when(() => incidenteService.porEstado(EstadoIncidente.CREADO))
        .thenAnswer((_) async => []);

    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();

    verify(() => incidenteService.porEstado(EstadoIncidente.CREADO)).called(1);
    expect(find.text('Centro de Comando'), findsOneWidget);
    expect(find.text('Comando Central'), findsOneWidget);
  });

  testWidgets('tab "Delegados" muestra el aviso de limitación (sin endpoint de historial)',
      (tester) async {
    when(() => incidenteService.porEstado(EstadoIncidente.CREADO))
        .thenAnswer((_) async => []);

    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delegados'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('requiere un endpoint adicional en el backend'),
      findsOneWidget,
    );
  });

  testWidgets(
      'confirmar derivación llama incidenteService.derivar(), refresca la lista '
      'y muestra el snackbar verde', (tester) async {
    when(() => incidenteService.porEstado(EstadoIncidente.CREADO))
        .thenAnswer((_) async => [_fake('i-001', EstadoIncidente.CREADO)]);
    when(() => incidenteService.derivar('i-001')).thenAnswer((_) async {});

    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Derivar a CAI'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar derivación'));
    await tester.pumpAndSettle();

    verify(() => incidenteService.derivar('i-001')).called(1);
    verify(() => incidenteService.porEstado(EstadoIncidente.CREADO)).called(2);
    expect(find.text('Incidente derivado al CAI más cercano.'), findsOneWidget);
  });

  testWidgets('botón "X" del sheet de derivación lo cierra sin llamar a derivar()',
      (tester) async {
    when(() => incidenteService.porEstado(EstadoIncidente.CREADO))
        .thenAnswer((_) async => [_fake('i-001', EstadoIncidente.CREADO)]);

    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Derivar a CAI'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Derivar a CAI'), findsOneWidget); // el botón de la card sigue, el sheet no
    verifyNever(() => incidenteService.derivar(any()));
  });

  group('Diálogo "Generar invitación de agente"', () {
    testWidgets('con ID de CAI vacío, "Generar" no llama a generarInvitacion()',
        (tester) async {
      when(() => incidenteService.porEstado(EstadoIncidente.CREADO))
          .thenAnswer((_) async => []);

      await tester.pumpWidget(appDePrueba());
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.vpn_key_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Generar'));
      await tester.pumpAndSettle();

      verifyNever(() => caiService.generarInvitacion(any()));
      // El diálogo sigue abierto (nada bloqueó cerrarlo con éxito).
      expect(find.text('Generar invitación de agente'), findsOneWidget);
    });

    testWidgets(
        'con ID de CAI, genera la invitación y muestra el token + fecha de expiración',
        (tester) async {
      when(() => incidenteService.porEstado(EstadoIncidente.CREADO))
          .thenAnswer((_) async => []);
      when(() => caiService.generarInvitacion('cai-001')).thenAnswer(
        (_) async => InvitacionAgente(
          token: 'inv-abc123',
          unidadPolicialId: 'cai-001',
          fechaExpiracion: DateTime(2026, 6, 16, 12, 0),
        ),
      );

      await tester.pumpWidget(appDePrueba());
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.vpn_key_outlined));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'cai-001');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Generar'));
      await tester.pumpAndSettle();

      verify(() => caiService.generarInvitacion('cai-001')).called(1);
      expect(find.text('inv-abc123'), findsOneWidget);
      expect(find.textContaining('2026-06-16'), findsOneWidget);
      // Tras generar, el botón cambia de "Generar" a "Cerrar".
      expect(find.widgetWithText(TextButton, 'Cerrar'), findsOneWidget);
    });

    testWidgets('error de negocio (ApiException) al generar se muestra inline en el diálogo',
        (tester) async {
      when(() => incidenteService.porEstado(EstadoIncidente.CREADO))
          .thenAnswer((_) async => []);
      when(() => caiService.generarInvitacion('cai-inexistente')).thenThrow(
        const ApiException(
          type: ApiExceptionType.notFound,
          message: 'CAI no encontrado: cai-inexistente',
        ),
      );

      await tester.pumpWidget(appDePrueba());
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.vpn_key_outlined));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'cai-inexistente');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Generar'));
      await tester.pumpAndSettle();

      expect(find.text('CAI no encontrado: cai-inexistente'), findsOneWidget);
      // El diálogo NO avanza al estado "token generado".
      expect(find.text('ID del CAI'), findsOneWidget);
    });

    testWidgets('"Cancelar" cierra el diálogo sin llamar a generarInvitacion()',
        (tester) async {
      when(() => incidenteService.porEstado(EstadoIncidente.CREADO))
          .thenAnswer((_) async => []);

      await tester.pumpWidget(appDePrueba());
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.vpn_key_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Generar invitación de agente'), findsNothing);
      verifyNever(() => caiService.generarInvitacion(any()));
    });
  });

  testWidgets('tap en la card (fuera del botón) navega a DetalleIncidenteView',
      (tester) async {
    when(() => incidenteService.porEstado(EstadoIncidente.CREADO))
        .thenAnswer((_) async => [_fake('i-001', EstadoIncidente.CREADO)]);

    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Robos o asaltos').hitTestable().first);
    await tester.pumpAndSettle();

    expect(find.text('detalle_incidente'), findsOneWidget);
  });

  testWidgets(
      'botón de logout muestra confirmación antes de cerrar sesión (fix hallazgo #2)',
      (tester) async {
    when(() => incidenteService.porEstado(EstadoIncidente.CREADO))
        .thenAnswer((_) async => []);

    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();

    expect(find.text('¿Cerrar sesión?'), findsOneWidget);
    expect(sesion.isAuthenticated, isTrue);

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(sesion.isAuthenticated, isFalse);
    expect(find.text('role_selection'), findsOneWidget);
  });

  testWidgets('cancelar la confirmación de logout NO cierra la sesión',
      (tester) async {
    when(() => incidenteService.porEstado(EstadoIncidente.CREADO))
        .thenAnswer((_) async => []);

    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(sesion.isAuthenticated, isTrue);
    expect(find.text('role_selection'), findsNothing);
  });

  // Épica 8, Bloque 2, ítem 4.
  testWidgets('el botón de logout expone tooltip "Cerrar sesión" (accesibilidad)',
      (tester) async {
    when(() => incidenteService.porEstado(EstadoIncidente.CREADO))
        .thenAnswer((_) async => []);

    await tester.pumpWidget(appDePrueba());
    await tester.pumpAndSettle();

    expect(find.byTooltip('Cerrar sesión'), findsOneWidget);
  });

  // Bloque 4 (Épica 8) — pantalla chica (iPhone SE: 375x667 lógicos).
  group('Responsive — pantalla chica (375x667)', () {
    Future<void> conPantallaChica(WidgetTester tester, Future<void> Function() body) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await body();
    }

    testWidgets('sheet "Derivar a CAI" no desborda en pantalla chica '
        '(fix Bloque 4: isScrollControlled + SingleChildScrollView)',
        (tester) async {
      await conPantallaChica(tester, () async {
        when(() => incidenteService.porEstado(EstadoIncidente.CREADO))
            .thenAnswer((_) async => [_fake('i-001', EstadoIncidente.CREADO)]);

        await tester.pumpWidget(appDePrueba());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Derivar a CAI'));
        await tester.pumpAndSettle();

        // Si hubiera desbordado, pumpAndSettle habría lanzado una excepción
        // de overflow (FlutterError) antes de llegar aquí.
        expect(find.text('Confirmar derivación'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    testWidgets('diálogo de invitación con mensaje de error largo (~200 '
        'caracteres) no desborda en pantalla chica (fix Bloque 4: '
        'SingleChildScrollView en el content)', (tester) async {
      await conPantallaChica(tester, () async {
        final mensajeLargo = 'El CAI especificado no existe en el sistema. '
            'Verifica el identificador e intenta nuevamente. Si el '
            'problema persiste, contacta al administrador del sistema '
            'para confirmar que la unidad policial esté correctamente '
            'registrada en la base de datos.'; // ~280 caracteres
        when(() => incidenteService.porEstado(EstadoIncidente.CREADO))
            .thenAnswer((_) async => []);
        when(() => caiService.generarInvitacion(any())).thenThrow(
          ApiException(type: ApiExceptionType.notFound, message: mensajeLargo),
        );

        await tester.pumpWidget(appDePrueba());
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.vpn_key_outlined));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'cai-x');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Generar'));
        await tester.pumpAndSettle();

        expect(find.textContaining('no existe en el sistema'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  });
}