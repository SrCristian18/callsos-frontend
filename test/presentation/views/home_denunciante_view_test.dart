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
import 'package:CallSos/data/models/valueobject/ubicacion.dart';
import 'package:CallSos/data/services/auth_service.dart';
import 'package:CallSos/data/services/api_exception.dart';
import 'package:CallSos/data/services/geolocalizacion_service.dart';
import 'package:CallSos/data/services/incidente_service.dart';
import 'package:CallSos/data/services/secure_storage.dart';
import 'package:CallSos/presentation/viewmodels/crear_incidente_viewmodel.dart';
import 'package:CallSos/presentation/viewmodels/sesion_viewmodel.dart';
import 'package:CallSos/presentation/views/home_denunciante_view.dart';

/// Épica 5 (ruta técnica) — widget test de HomeDenuncianteView.
///
/// Es la vista más compleja de las 4 "home" por rol: además de la lista
/// (compartida vía IncidenteListViewModel, ya cubierto en
/// incidente_list_viewmodel_test.dart), tiene el flujo completo del botón
/// de pánico — FAB -> bottom sheet -> selección de tipo -> descripción ->
/// permiso GPS -> posición -> POST /incidentes -> refresco de la lista.
///
/// Ese flujo vive en CrearIncidenteViewModel (ya con su propio test,
/// crear_incidente_viewmodel_test.dart) — aquí NO se reprueba su lógica
/// interna, solo el CABLEADO: que la vista construya el VM con las
/// dependencias correctas, muestre sus estados, y reaccione bien al
/// resultado (cerrar el sheet, refrescar la lista, mostrar el snackbar).
class MockAuthService extends Mock implements IAuthService {}

class MockIncidenteService extends Mock implements IIncidenteService {}

class MockGeolocalizacionService extends Mock implements IGeolocalizacionService {}

class FakeSecureStorage implements ISecureStorage {
  final Map<String, String> _datos = {};
  @override
  Future<String?> read(String key) async => _datos[key];
  @override
  Future<void> write(String key, String value) async => _datos[key] = value;
  @override
  Future<void> delete(String key) async => _datos.remove(key);
}

/// Localiza el `GestureDetector` que envuelve el chip de tipo de
/// emergencia con [titulo] (el área táctil real es ese GestureDetector,
/// no el `Text` — tocar el `Text` directamente puede fallar el hit test).
Finder _chipDeTipo(String titulo) =>
    find.ancestor(of: find.text(titulo), matching: find.byType(GestureDetector)).first;

// FIX: el grid de tipos tiene 7 items (2 columnas -> 4 filas). Con el
// header del sheet (ícono, título, subtítulo, label "Tipo de emergencia")
// ocupando espacio arriba, chips de filas inferiores — como "Robos o
// asaltos" (índice 5, 3ª fila) — quedan fuera del viewport visible de la
// `SingleChildScrollView` sin hacer scroll. `tester.tap()` calculaba el
// centro del widget con `getCenter()` en esa posición fuera de pantalla,
// y el hit test real (que sí respeta el recorte del scroll) no
// encontraba nada ahí — de ahí el warning "would not hit test on the
// specified widget" y que `vm.seleccionarTipo()` nunca se llamara
// (dejando el flujo entero sin poder avanzar en los 3 tests que lo usan).
//
// Fix: `tester.ensureVisible()` hace scroll dentro del `Scrollable`
// ancestro más cercano (aquí, la `SingleChildScrollView` del sheet) hasta
// que el chip quede dentro del viewport, antes de tocarlo.
Future<void> _tocarChipDeTipo(WidgetTester tester, String titulo) async {
  final chip = _chipDeTipo(titulo);
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
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
  // FIX: `any(named: 'tipo')` / `any(named: 'ubicacion')` usan tipos custom
  // (no primitivos), así que mocktail exige un fallback registrado. Sin
  // esto, el primer test que use any() sobre estos tipos revienta con
  // StateError — y ese crash deja el estado interno de mocktail corrupto
  // para el/los tests siguientes (se manifestó como un error de
  // "ArgumentMatcher... denuncianteId" en un when() de OTRO test que ni
  // siquiera usaba any()).
  setUpAll(() {
    registerFallbackValue(TipoIncidenteEnum.ROBOS_O_ASALTOS);
    registerFallbackValue(Ubicacion(latitud: 0, longitud: 0));
  });

  late MockAuthService authService;
  late MockIncidenteService incidenteService;
  late MockGeolocalizacionService geoService;
  late SesionViewModel sesion;
  late CrearIncidenteViewModel crearVm;

  setUp(() async {
    authService = MockAuthService();
    incidenteService = MockIncidenteService();
    geoService = MockGeolocalizacionService();
    sesion = SesionViewModel(authService: authService, storage: FakeSecureStorage());
    crearVm = CrearIncidenteViewModel(
        incidenteService: incidenteService, geoService: geoService);

    when(() => authService.login(username: 'den-001', password: '1234')).thenAnswer(
      (_) async => const AuthResult(
          token: 'jwt-den', actorId: 'den-001', rol: Rol.DENUNCIANTE, nombre: 'Ana Denunciante'),
    );
    await sesion.login(username: 'den-001', password: '1234');
  });

  Widget appDePrueba() {
    return MultiProvider(
      providers: [
        Provider<IIncidenteService>.value(value: incidenteService),
        ChangeNotifierProvider<SesionViewModel>.value(value: sesion),
        ChangeNotifierProvider<CrearIncidenteViewModel>.value(value: crearVm),
      ],
      child: MaterialApp(
        home: const HomeDenuncianteView(),
        routes: {
          AppRoutes.detalleIncidente: (_) => const Scaffold(body: Text('detalle_incidente')),
          AppRoutes.roleSelection: (_) => const Scaffold(body: Text('role_selection')),
        },
      ),
    );
  }

  group('AppBar y lista', () {
    testWidgets('carga /mis-incidentes al iniciar y muestra el nombre del denunciante',
        (tester) async {
      when(() => incidenteService.misIncidentes()).thenAnswer((_) async => []);

      await tester.pumpWidget(appDePrueba());
      await tester.pumpAndSettle();

      verify(() => incidenteService.misIncidentes()).called(1);
      expect(find.text('CallSOS'), findsOneWidget);
      expect(find.text('Ana Denunciante'), findsOneWidget);
    });

    testWidgets('lista vacía muestra el mensaje contextual del denunciante', (tester) async {
      when(() => incidenteService.misIncidentes()).thenAnswer((_) async => []);

      await tester.pumpWidget(appDePrueba());
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Aún no has reportado ninguna emergencia'),
        findsOneWidget,
      );
    });

    testWidgets('incidente activo (CREADO) muestra botón "Cancelar emergencia"',
        (tester) async {
      when(() => incidenteService.misIncidentes())
          .thenAnswer((_) async => [_fake('i-001', EstadoIncidente.CREADO)]);

      await tester.pumpWidget(appDePrueba());
      await tester.pumpAndSettle();

      expect(find.text('Cancelar emergencia'), findsOneWidget);
    });

    testWidgets('incidente FINALIZADO no muestra botón de acción', (tester) async {
      when(() => incidenteService.misIncidentes())
          .thenAnswer((_) async => [_fake('i-002', EstadoIncidente.FINALIZADO)]);

      await tester.pumpWidget(appDePrueba());
      await tester.pumpAndSettle();

      expect(find.text('Cancelar emergencia'), findsNothing);
    });

    testWidgets(
        'tocar "Cancelar emergencia" muestra el diálogo de confirmación '
        'y NO llama a cancelar() todavía (Épica 8, Bloque 1)', (tester) async {
      when(() => incidenteService.misIncidentes())
          .thenAnswer((_) async => [_fake('i-003', EstadoIncidente.CREADO)]);

      await tester.pumpWidget(appDePrueba());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancelar emergencia'));
      await tester.pumpAndSettle();

      expect(find.text('¿Cancelar emergencia?'), findsOneWidget);
      expect(find.text('Sí, cancelar'), findsOneWidget);
      expect(find.text('No, volver'), findsOneWidget);
      verifyNever(() => incidenteService.cancelar(any()));
    });

    testWidgets('en el diálogo, "No, volver" cierra el diálogo sin cancelar nada',
        (tester) async {
      when(() => incidenteService.misIncidentes())
          .thenAnswer((_) async => [_fake('i-003', EstadoIncidente.CREADO)]);

      await tester.pumpWidget(appDePrueba());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancelar emergencia'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No, volver'));
      await tester.pumpAndSettle();

      expect(find.text('¿Cancelar emergencia?'), findsNothing);
      verifyNever(() => incidenteService.cancelar(any()));
      // La card sigue como estaba — nada de esto refrescó la lista.
      verify(() => incidenteService.misIncidentes()).called(1);
    });

    testWidgets(
        'en el diálogo, "Sí, cancelar" llama service.cancelar(), refresca la lista '
        'y muestra el snackbar naranja', (tester) async {
      when(() => incidenteService.misIncidentes())
          .thenAnswer((_) async => [_fake('i-003', EstadoIncidente.CREADO)]);
      when(() => incidenteService.cancelar('i-003')).thenAnswer((_) async {});

      await tester.pumpWidget(appDePrueba());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancelar emergencia'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sí, cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('¿Cancelar emergencia?'), findsNothing);
      verify(() => incidenteService.cancelar('i-003')).called(1);
      verify(() => incidenteService.misIncidentes()).called(2); // carga inicial + refresco
      expect(find.text('Emergencia cancelada.'), findsOneWidget);
    });

    testWidgets('tap en la card (fuera del botón) navega a DetalleIncidenteView',
        (tester) async {
      when(() => incidenteService.misIncidentes())
          .thenAnswer((_) async => [_fake('i-004', EstadoIncidente.CREADO)]);

      await tester.pumpWidget(appDePrueba());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Robos o asaltos').hitTestable().first);
      await tester.pumpAndSettle();

      expect(find.text('detalle_incidente'), findsOneWidget);
    });

    testWidgets(
        'botón de logout muestra confirmación antes de cerrar sesión (fix hallazgo #2)',
        (tester) async {
      when(() => incidenteService.misIncidentes()).thenAnswer((_) async => []);

      await tester.pumpWidget(appDePrueba());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();

      // Antes del fix, tocar el ícono deslogueaba inmediatamente. Ahora
      // debe aparecer un diálogo y la sesión debe seguir activa hasta
      // que se confirme.
      expect(find.text('¿Cerrar sesión?'), findsOneWidget);
      expect(sesion.isAuthenticated, isTrue);

      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();

      expect(sesion.isAuthenticated, isFalse);
      expect(find.text('role_selection'), findsOneWidget);
    });

    testWidgets('cancelar la confirmación de logout NO cierra la sesión',
        (tester) async {
      when(() => incidenteService.misIncidentes()).thenAnswer((_) async => []);

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
  });

  group('FAB "EMERGENCIA" — bottom sheet de creación', () {
    testWidgets('abre el bottom sheet y resetea el VM (por si tenía estado de un uso previo)',
        (tester) async {
      when(() => incidenteService.misIncidentes()).thenAnswer((_) async => []);
      // Deja el VM "sucio" antes de abrir, para probar que resetear() se llama.
      crearVm.seleccionarTipo(TipoIncidenteEnum.ROBOS_O_ASALTOS);
      crearVm.descripcion = 'texto viejo de un uso anterior';

      await tester.pumpWidget(appDePrueba());
      await tester.pumpAndSettle();

      await tester.tap(find.text('EMERGENCIA'));
      await tester.pumpAndSettle();

      expect(find.text('¿Qué está ocurriendo?'), findsOneWidget);
      expect(crearVm.tipoSeleccionado, isNull);
      expect(crearVm.descripcion, isEmpty);
    });

    testWidgets('botón "Reportar emergencia" deshabilitado sin tipo ni descripción',
        (tester) async {
      when(() => incidenteService.misIncidentes()).thenAnswer((_) async => []);

      await tester.pumpWidget(appDePrueba());
      await tester.pumpAndSettle();
      await tester.tap(find.text('EMERGENCIA'));
      await tester.pumpAndSettle();

      final boton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Reportar emergencia'),
      );
      expect(boton.onPressed, isNull);
    });

    testWidgets(
        'flujo completo exitoso: selecciona tipo, escribe descripción, envía -> '
        'crea el incidente con denuncianteId del actor autenticado, cierra el sheet, '
        'refresca la lista y muestra el snackbar de éxito', (tester) async {
      when(() => incidenteService.misIncidentes()).thenAnswer((_) async => []);
      when(() => geoService.solicitarPermiso())
          .thenAnswer((_) async => PermisoGpsResultado.concedido);
      when(() => geoService.obtenerPosicionActual(precisionAlta: true)).thenAnswer(
          (_) async => Ubicacion(latitud: 10.391, longitud: -75.4794));
      when(() => incidenteService.crear(
            denuncianteId: 'den-001',
            tipo: TipoIncidenteEnum.ROBOS_O_ASALTOS,
            descripcion: 'Me están robando',
            ubicacion: Ubicacion(latitud: 10.391, longitud: -75.4794),
          )).thenAnswer((_) async => _fake('i-nuevo', EstadoIncidente.CREADO));

      await tester.pumpWidget(appDePrueba());
      await tester.pumpAndSettle();
      await tester.tap(find.text('EMERGENCIA'));
      await tester.pumpAndSettle();

      await _tocarChipDeTipo(tester, 'Robos o asaltos');
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Me están robando');
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Reportar emergencia'));
      await tester.pumpAndSettle();

      verify(() => incidenteService.crear(
            denuncianteId: 'den-001',
            tipo: TipoIncidenteEnum.ROBOS_O_ASALTOS,
            descripcion: 'Me están robando',
            ubicacion: Ubicacion(latitud: 10.391, longitud: -75.4794),
          )).called(1);
      // El sheet se cierra (su título ya no está) y la lista se refrescó.
      expect(find.text('¿Qué está ocurriendo?'), findsNothing);
      verify(() => incidenteService.misIncidentes()).called(2);
      expect(find.textContaining('Emergencia reportada'), findsOneWidget);
    });

    testWidgets('GPS desactivado: muestra el mensaje de error inline y NO llama a crear()',
        (tester) async {
      when(() => incidenteService.misIncidentes()).thenAnswer((_) async => []);
      when(() => geoService.solicitarPermiso())
          .thenAnswer((_) async => PermisoGpsResultado.servicioDesactivado);

      await tester.pumpWidget(appDePrueba());
      await tester.pumpAndSettle();
      await tester.tap(find.text('EMERGENCIA'));
      await tester.pumpAndSettle();

      await _tocarChipDeTipo(tester, 'Robos o asaltos');
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'algo');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Reportar emergencia'));
      await tester.pumpAndSettle();

      expect(find.textContaining('El GPS está desactivado'), findsOneWidget);
      verifyNever(() => incidenteService.crear(
            denuncianteId: any(named: 'denuncianteId'),
            tipo: any(named: 'tipo'),
            descripcion: any(named: 'descripcion'),
            ubicacion: any(named: 'ubicacion'),
          ));
    });

    testWidgets('error de negocio del backend (ApiException) se muestra inline en el sheet',
        (tester) async {
      when(() => incidenteService.misIncidentes()).thenAnswer((_) async => []);
      when(() => geoService.solicitarPermiso())
          .thenAnswer((_) async => PermisoGpsResultado.concedido);
      when(() => geoService.obtenerPosicionActual(precisionAlta: true)).thenAnswer(
          (_) async => Ubicacion(latitud: 10.391, longitud: -75.4794));
      when(() => incidenteService.crear(
            denuncianteId: any(named: 'denuncianteId'),
            tipo: any(named: 'tipo'),
            descripcion: any(named: 'descripcion'),
            ubicacion: any(named: 'ubicacion'),
          )).thenThrow(const ApiException(
        type: ApiExceptionType.badRequest,
        message: 'descripcion: La descripción es obligatoria',
      ));

      await tester.pumpWidget(appDePrueba());
      await tester.pumpAndSettle();
      await tester.tap(find.text('EMERGENCIA'));
      await tester.pumpAndSettle();

      await _tocarChipDeTipo(tester, 'Robos o asaltos');
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'algo');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Reportar emergencia'));
      await tester.pumpAndSettle();

      expect(find.text('descripcion: La descripción es obligatoria'), findsOneWidget);
      // El sheet NO se cierra en error — el usuario debe poder corregir y reintentar.
      expect(find.text('¿Qué está ocurriendo?'), findsOneWidget);
    });

    testWidgets('botón "Cancelar" del sheet lo cierra sin crear nada', (tester) async {
      when(() => incidenteService.misIncidentes()).thenAnswer((_) async => []);

      await tester.pumpWidget(appDePrueba());
      await tester.pumpAndSettle();
      await tester.tap(find.text('EMERGENCIA'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('¿Qué está ocurriendo?'), findsNothing);
      verifyNever(() => incidenteService.crear(
            denuncianteId: any(named: 'denuncianteId'),
            tipo: any(named: 'tipo'),
            descripcion: any(named: 'descripcion'),
            ubicacion: any(named: 'ubicacion'),
          ));
    });
  });
}