import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:CallSos/core/colores_app.dart';
import 'package:CallSos/data/models/eta_info.dart';
import 'package:CallSos/data/services/incidente_service.dart';
import 'package:CallSos/data/services/stomp_service.dart';
import 'package:CallSos/presentation/widgets/eta_widget.dart';

/// EPIC-09 (Design System, auditoría UX/UI) — "estados de ETA más
/// claros": antes de esta épica los 3 estados de [EtaWidget] (calculando
/// / con datos / error) se distinguían SOLO por el texto — acá se
/// confirma que ahora también cambian el ícono y el color de acento,
/// sin que el texto de cada estado (ya cubierto por
/// `detalle_incidente_view_test.dart`) haya cambiado.
class MockIncidenteService extends Mock implements IIncidenteService {}

class MockStompService extends Mock implements IStompService {}

void main() {
  late MockIncidenteService incidenteService;
  late MockStompService stomp;

  Widget appDePrueba() {
    return MaterialApp(
      home: Scaffold(
        body: MultiProvider(
          providers: [
            Provider<IIncidenteService>.value(value: incidenteService),
            Provider<IStompService>.value(value: stomp),
          ],
          child: const EtaWidget(incidenteId: 'inc-1'),
        ),
      ),
    );
  }

  Container cajaIcono(WidgetTester tester) {
    return tester.widget<Container>(find.byKey(const ValueKey('eta_icono_box')));
  }

  Color colorDe(Container c) => (c.decoration as BoxDecoration).color!;

  setUp(() {
    incidenteService = MockIncidenteService();
    stomp = MockStompService();
    // Por defecto, conectar() nunca resuelve sus callbacks — cada grupo
    // de tests decide si/cuándo dispara onConnected/onError.
    when(() => stomp.conectar(
          onConnected: any(named: 'onConnected'),
          onError: any(named: 'onError'),
        )).thenAnswer((_) async {});
    when(() => stomp.desconectar()).thenAnswer((_) async {});
  });

  group('Estado "calculando"', () {
    testWidgets('muestra un ícono distinto (sync) al de éxito/error, color verde',
        (tester) async {
      when(() => incidenteService.consultarEta('inc-1'))
          .thenAnswer((_) async => const EtaInfo.sinDatos());

      await tester.pumpWidget(appDePrueba());
      await tester.pump();

      expect(find.text('Calculando tiempo estimado de llegada...'), findsOneWidget);
      expect(find.byIcon(Icons.sync), findsOneWidget);
      expect(find.byIcon(Icons.timer_outlined), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsNothing);
      // Deliberadamente NO es un spinner animado: ver el comentario de
      // `_EtaEstadoVisual` en eta_widget.dart — un `CircularProgressIndicator`
      // acá haría que cualquier `pumpAndSettle()` con la conexión sin
      // resolver (como en `detalle_incidente_view_test.dart`) cuelgue.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(colorDe(cajaIcono(tester)), AppColors.verdeOscuro);
    });
  });

  group('Estado "con datos"', () {
    testWidgets('muestra ícono de reloj (no spinner) y color verde', (tester) async {
      when(() => incidenteService.consultarEta('inc-1')).thenAnswer(
        (_) async => const EtaInfo(
          minutosEstimados: 8,
          categoriaDistancia: CategoriaDistancia.MENOS_DE_1_KM,
        ),
      );

      await tester.pumpWidget(appDePrueba());
      await tester.pump();

      expect(find.textContaining('~8 min'), findsOneWidget);
      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(colorDe(cajaIcono(tester)), AppColors.verdeOscuro);
    });
  });

  group('Estado "error"', () {
    testWidgets('muestra ícono de error (no spinner) y color rojo', (tester) async {
      when(() => incidenteService.consultarEta('inc-1'))
          .thenThrow(Exception('sin red'));
      when(() => stomp.conectar(
            onConnected: any(named: 'onConnected'),
            onError: any(named: 'onError'),
          )).thenAnswer((invocation) async {
        final onError =
            invocation.namedArguments[#onError] as void Function(String);
        onError('falló la conexión');
      });

      await tester.pumpWidget(appDePrueba());
      await tester.pump();

      expect(
        find.text('No se pudo conectar para recibir actualizaciones '
            'en tiempo real.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(colorDe(cajaIcono(tester)), AppColors.error);
    });
  });

  group('Regresión: la conexión que nunca resuelve no cuelga pumpAndSettle', () {
    testWidgets(
        'con consultarEta() sin stub y conectar() sin invocar sus callbacks '
        '(igual que en detalle_incidente_view_test.dart), pumpAndSettle() termina',
        (tester) async {
      // A propósito NO se stubea `consultarEta` (mocktail lo hace tirar
      // MissingStubError, que EtaViewModel.iniciar() atrapa en su propio
      // try/catch) y `conectar()` usa el stub por defecto del setUp
      // (nunca llama a onConnected/onError) — mismo escenario exacto
      // que dejaba a EtaConexionEstado.conectando indefinidamente en
      // detalle_incidente_view_test.dart.
      await tester.pumpWidget(appDePrueba());
      await tester.pumpAndSettle();

      expect(find.text('Calculando tiempo estimado de llegada...'), findsOneWidget);
    });
  });
}