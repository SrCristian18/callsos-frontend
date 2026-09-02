import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:CallSos/data/models/enums/estado_incidente.dart';
import 'package:CallSos/data/models/enums/tipo_incidente_enum.dart';
import 'package:CallSos/data/models/incidente.dart';
import 'package:CallSos/data/services/api_exception.dart';
import 'package:CallSos/data/services/incidente_service.dart';
import 'package:CallSos/presentation/viewmodels/incidente_list_viewmodel.dart';
import 'package:CallSos/presentation/widgets/empty_state.dart';
import 'package:CallSos/presentation/widgets/error_view.dart';
import 'package:CallSos/presentation/widgets/incidente_card.dart';
import 'package:CallSos/presentation/widgets/incidente_list_body.dart';
import 'package:CallSos/presentation/widgets/loading_view.dart';

/// EPIC-09 (Design System, auditoría UX/UI) — checklist §18
/// (loading/success/error/empty) para `IncidenteListBody`, el widget que
/// `home_denunciante_view` (y el resto de Homes) usa para su lista.
///
/// Antes de esta épica, cada uno de los 3 estados sin datos tenía acá un
/// bloque hecho a mano; este archivo confirma que ahora ES
/// [LoadingView]/[ErrorView]/[EmptyState] (los componentes de EPIC-03) los
/// que se renderizan, sin cambiar ningún texto/comportamiento visible
/// para quien usa la app.
class MockIncidenteService extends Mock implements IIncidenteService {}

Incidente _fake(String id) => Incidente(
      id: id,
      fechaHora: DateTime(2026, 6, 14),
      tipo: TipoIncidenteEnum.ROBOS_O_ASALTOS,
      descripcion: 'desc $id',
      estado: EstadoIncidente.CREADO,
      latitud: 10.391,
      longitud: -75.4794,
      denuncianteId: 'den-001',
    );

void main() {
  late MockIncidenteService service;
  late IncidenteListViewModel vm;

  Widget appDePrueba() {
    return MaterialApp(
      home: Scaffold(
        body: ListenableBuilder(
          listenable: vm,
          builder: (_, _) => IncidenteListBody(
            vm: vm,
            incidentes: vm.incidentes,
            buildCard: (inc) => IncidenteCard(incidente: inc),
          ),
        ),
      ),
    );
  }

  setUp(() {
    service = MockIncidenteService();
  });

  group('Loading', () {
    testWidgets('muestra LoadingView mientras carga por primera vez', (tester) async {
      // Un Completer que nunca se resuelve dentro de este test deja al
      // VM "congelado" en isLoading == true — sin usar Future.delayed
      // (que arma un Timer real que flutter_test reporta como pendiente
      // si el test termina antes de que dispare).
      final completer = Completer<List<Incidente>>();
      when(() => service.misIncidentes()).thenAnswer((_) => completer.future);
      vm = IncidenteListViewModel(service: service, fetchFn: service.misIncidentes);
      unawaited(vm.cargar());

      await tester.pumpWidget(appDePrueba());
      await tester.pump();

      expect(find.byType(LoadingView), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Resolvemos el completer para no dejar el future colgando al
      // terminar el test (aunque no use un Timer, es buena práctica).
      completer.complete([]);
      await tester.pumpAndSettle();
    });
  });

  group('Error (sin datos previos)', () {
    testWidgets('muestra ErrorView con el mensaje y "Reintentar" llama a vm.cargar()',
        (tester) async {
      when(() => service.misIncidentes()).thenThrow(
        const ApiException(type: ApiExceptionType.noConnection, message: 'Sin conexión.'),
      );
      vm = IncidenteListViewModel(service: service, fetchFn: service.misIncidentes);
      await vm.cargar();

      await tester.pumpWidget(appDePrueba());
      await tester.pump();

      expect(find.byType(ErrorView), findsOneWidget);
      expect(find.text('Sin conexión.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);

      when(() => service.misIncidentes()).thenAnswer((_) async => [_fake('i-1')]);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorView), findsNothing);
      verify(() => service.misIncidentes()).called(2);
    });
  });

  group('Empty', () {
    testWidgets('lista vacía sin error muestra EmptyState con el mensaje e ícono provistos',
        (tester) async {
      when(() => service.misIncidentes()).thenAnswer((_) async => []);
      vm = IncidenteListViewModel(service: service, fetchFn: service.misIncidentes);
      await vm.cargar();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: vm,
            builder: (_, _) => IncidenteListBody(
              vm: vm,
              incidentes: vm.incidentes,
              buildCard: (inc) => IncidenteCard(incidente: inc),
              mensajeVacio: 'Aún no has reportado ninguna emergencia.',
              iconoVacio: Icons.emergency_share_outlined,
            ),
          ),
        ),
      ));
      await tester.pump();

      final empty = tester.widget<EmptyState>(find.byType(EmptyState));
      expect(empty.message, 'Aún no has reportado ninguna emergencia.');
      expect(empty.icon, Icons.emergency_share_outlined);
    });
  });

  group('Success (con datos)', () {
    testWidgets('muestra una IncidenteCard por cada incidente, sin loading/error/empty',
        (tester) async {
      when(() => service.misIncidentes())
          .thenAnswer((_) async => [_fake('i-1'), _fake('i-2')]);
      vm = IncidenteListViewModel(service: service, fetchFn: service.misIncidentes);
      await vm.cargar();

      await tester.pumpWidget(appDePrueba());
      await tester.pump();

      expect(find.byType(IncidenteCard), findsNWidgets(2));
      expect(find.byType(LoadingView), findsNothing);
      expect(find.byType(ErrorView), findsNothing);
      expect(find.byType(EmptyState), findsNothing);
    });

    testWidgets('con datos previos, un error posterior se muestra como banner '
        '(no reemplaza la lista con un ErrorView de página completa)', (tester) async {
      when(() => service.misIncidentes()).thenAnswer((_) async => [_fake('i-1')]);
      vm = IncidenteListViewModel(service: service, fetchFn: service.misIncidentes);
      await vm.cargar();

      when(() => service.misIncidentes()).thenThrow(
        const ApiException(type: ApiExceptionType.noConnection, message: 'Sin conexión.'),
      );
      await vm.refrescar();

      await tester.pumpWidget(appDePrueba());
      await tester.pump();

      // La card sigue visible...
      expect(find.byType(IncidenteCard), findsOneWidget);
      // ...y el error se ve como banner, no como ErrorView de página
      // completa (que ocultaría la lista que el usuario sigue teniendo).
      expect(find.byType(ErrorView), findsNothing);
      expect(find.text('Sin conexión.'), findsOneWidget);
    });
  });
}