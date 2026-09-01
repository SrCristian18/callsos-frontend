import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:CallSos/data/models/auditoria_incidente.dart';
import 'package:CallSos/data/models/enums/estado_incidente.dart';
import 'package:CallSos/data/services/api_exception.dart';
import 'package:CallSos/data/services/auditoria_service.dart';
import 'package:CallSos/presentation/widgets/timeline.dart';

/// EPIC-07 — widget test de `Timeline`.
///
/// Igual que `EtaWidget`, el widget gestiona su propia carga/estado, así
/// que el test lo monta con un `IAuditoriaService` mockeado vía Provider
/// (mismo patrón que `detalle_incidente_view_test.dart` usa para
/// `IIncidenteService`).
class MockAuditoriaService extends Mock implements IAuditoriaService {}

AuditoriaIncidente _evento({
  String incidenteId = 'inc-001',
  EstadoIncidente? estadoAnterior,
  EstadoIncidente estadoNuevo = EstadoIncidente.CREADO,
  String actorId = 'den-001',
  String actorRol = 'DENUNCIANTE',
  DateTime? timestamp,
  String detalle = 'Incidente creado.',
  String? campo,
  String? valorAnteriorGenerico,
  String? valorNuevoGenerico,
}) {
  return AuditoriaIncidente(
    incidenteId: incidenteId,
    estadoAnterior: estadoAnterior,
    estadoNuevo: estadoNuevo,
    actorId: actorId,
    actorRol: actorRol,
    timestamp: timestamp ?? DateTime(2026, 6, 14, 10, 0),
    detalle: detalle,
    campo: campo,
    valorAnteriorGenerico: valorAnteriorGenerico,
    valorNuevoGenerico: valorNuevoGenerico,
  );
}

void main() {
  late MockAuditoriaService service;

  setUp(() {
    service = MockAuditoriaService();
  });

  Widget appDePrueba(String incidenteId) {
    return MultiProvider(
      providers: [
        Provider<IAuditoriaService>.value(value: service),
      ],
      child: MaterialApp(
        home: Scaffold(body: Timeline(incidenteId: incidenteId)),
      ),
    );
  }

  testWidgets('muestra el spinner de carga mientras espera la respuesta',
      (tester) async {
    when(() => service.historial('inc-001')).thenAnswer(
      (_) => Future.delayed(const Duration(milliseconds: 500), () => []),
    );

    await tester.pumpWidget(appDePrueba('inc-001'));
    await tester.pump();

    expect(find.text('Cargando historial...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // FIX: evita "pending timer" — deja resolver el Future pendiente
    // antes de que termine el test.
    await tester.pumpAndSettle();
  });

  testWidgets('lista vacía muestra el EmptyState, no un error', (tester) async {
    when(() => service.historial('inc-001')).thenAnswer((_) async => []);

    await tester.pumpWidget(appDePrueba('inc-001'));
    await tester.pumpAndSettle();

    expect(find.text('Todavía no hay eventos registrados.'), findsOneWidget);
    expect(find.byIcon(Icons.history_toggle_off), findsOneWidget);
  });

  testWidgets(
      'con eventos, muestra fecha, actor+rol y detalle de cada uno, en orden',
      (tester) async {
    when(() => service.historial('inc-001')).thenAnswer((_) async => [
          _evento(
            estadoNuevo: EstadoIncidente.CREADO,
            actorId: 'den-001',
            actorRol: 'DENUNCIANTE',
            detalle: 'Incidente creado.',
            timestamp: DateTime(2026, 6, 14, 10, 0),
          ),
          _evento(
            estadoAnterior: EstadoIncidente.CREADO,
            estadoNuevo: EstadoIncidente.DERIVADO_A_CAI,
            actorId: 'com-001',
            actorRol: 'COMANDO',
            detalle: 'Derivado al CAI más cercano.',
            timestamp: DateTime(2026, 6, 14, 10, 5),
          ),
        ]);

    await tester.pumpWidget(appDePrueba('inc-001'));
    await tester.pumpAndSettle();

    expect(find.text('Incidente creado.'), findsOneWidget);
    expect(find.text('Derivado al CAI más cercano.'), findsOneWidget);
    expect(find.textContaining('Denunciante · den-001'), findsOneWidget);
    expect(find.textContaining('Comando · com-001'), findsOneWidget);
  });

  testWidgets(
      'cambio de campo genérico muestra el chip "campo: antes → después" '
      'en vez del badge de estado', (tester) async {
    when(() => service.historial('inc-001')).thenAnswer((_) async => [
          _evento(
            estadoNuevo: EstadoIncidente.DERIVADO_A_CAI,
            campo: 'tipo',
            valorAnteriorGenerico: 'ROBOS_O_ASALTOS',
            valorNuevoGenerico: 'RIÑAS_O_PELEAS',
            detalle: 'El denunciante actualizó el tipo de incidente.',
          ),
        ]);

    await tester.pumpWidget(appDePrueba('inc-001'));
    await tester.pumpAndSettle();

    expect(find.textContaining('tipo: ROBOS_O_ASALTOS → RIÑAS_O_PELEAS'),
        findsOneWidget);
  });

  testWidgets('error de carga (ApiException) muestra el mensaje y '
      '"Reintentar" recarga', (tester) async {
    when(() => service.historial('inc-001')).thenThrow(
      const ApiException(
        type: ApiExceptionType.forbidden,
        message: 'No tiene autorización para consultar la auditoría de este incidente.',
      ),
    );

    await tester.pumpWidget(appDePrueba('inc-001'));
    await tester.pumpAndSettle();

    expect(
      find.text('No tiene autorización para consultar la auditoría de este incidente.'),
      findsOneWidget,
    );

    when(() => service.historial('inc-001')).thenAnswer((_) async => []);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Todavía no hay eventos registrados.'), findsOneWidget);
    verify(() => service.historial('inc-001')).called(2);
  });
}