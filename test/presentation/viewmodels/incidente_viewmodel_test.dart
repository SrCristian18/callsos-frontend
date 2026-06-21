import 'package:flutter_test/flutter_test.dart';

import 'package:CallSos/data/models/agente_policia.dart';
import 'package:CallSos/data/models/enums/estado_agente.dart';
import 'package:CallSos/data/models/enums/estado_incidente.dart';
import 'package:CallSos/data/models/enums/rol.dart';
import 'package:CallSos/data/models/tipo_incidente.dart';
import 'package:CallSos/presentation/viewmodels/incidente_viewmodel.dart';

/// F.7 — Tests del IncidenteViewModel LEGACY (estado en memoria/mock).
///
/// NOTA IMPORTANTE: este ViewModel es el remanente del flujo original
/// pre-F.2 (`incidente_view.dart` + `comando_widget`/`jefecai_widget`/
/// `agente_widget`), ya reemplazado funcionalmente por las Home views
/// reales (F.2: HomeComandoView, HomeCAIView, HomeAgenteView, conectadas
/// a `IIncidenteService`/`IncidenteListViewModel`).
///
/// Se testea TAL COMO ES HOY (mock en memoria, sin red) porque:
/// - Sigue siendo parte del código compilable del proyecto (rutas legacy
///   `/incident_view`, `/report_view` en AppRoutes).
/// - F.7 no incluye su reescritura — eso es trabajo de una fase de
///   "retiro de legacy" posterior, fuera del alcance actual.
///
/// Estos tests documentan el comportamiento legacy y sirven de red de
/// seguridad si alguien lo toca antes de su retiro definitivo.
void main() {
  late AgentePolicia comando;
  late IncidenteViewModel vm;

  setUp(() {
    comando = AgentePolicia(
      id: 'comando-1',
      nombre: 'Oficial de Prueba',
      rol: Rol.COMANDO,
      cai: 'CAI San Francisco',
      estadoAgente: EstadoAgente.DISPONIBLE,
    );
    vm = IncidenteViewModel(currentUser: comando);
  });

  group('estado inicial', () {
    test('currentUser es el provisto en el constructor', () {
      expect(vm.currentUser.id, 'comando-1');
      expect(vm.currentUser.rol, Rol.COMANDO);
    });

    test('isLoading inicia en false', () {
      expect(vm.isLoading, isFalse);
    });

    test('catalogTypes tiene al menos un tipo (catálogo mock legacy)', () {
      expect(vm.catalogTypes, isNotEmpty);
      expect(vm.catalogTypes.first, isA<TipoIncidente>());
    });

    test('hay un incidente mock inicial en estado CREADO', () {
      expect(vm.incidentosReportados, isNotEmpty);
      expect(vm.incidentosReportados.first.estado, EstadoIncidente.CREADO);
    });
  });

  group('actualizarUsuario (F.0.4)', () {
    test('actualiza currentUser y notifica si cambia id o rol', () {
      var notificado = false;
      vm.addListener(() => notificado = true);

      final nuevoAgente = AgentePolicia(
        id: 'agente-001',
        nombre: 'Pedro Agente',
        rol: Rol.AGENTE,
        estadoAgente: EstadoAgente.DISPONIBLE,
      );

      vm.actualizarUsuario(nuevoAgente);

      expect(vm.currentUser.id, 'agente-001');
      expect(vm.currentUser.rol, Rol.AGENTE);
      expect(notificado, isTrue);
    });

    test('NO notifica si id y rol son iguales (evita rebuilds innecesarios)',
        () {
      var notificaciones = 0;
      vm.addListener(() => notificaciones++);

      // Mismo id y mismo rol que el actual (comando), solo cambia nombre.
      final mismoUsuarioDistintoNombre = AgentePolicia(
        id: 'comando-1',
        nombre: 'Nombre Distinto',
        rol: Rol.COMANDO,
        cai: 'Otro CAI',
        estadoAgente: EstadoAgente.OCUPADO,
      );

      vm.actualizarUsuario(mismoUsuarioDistintoNombre);

      expect(notificaciones, 0);
      // El objeto currentUser tampoco se reemplaza (sigue siendo el original).
      expect(vm.currentUser.nombre, 'Oficial de Prueba');
    });

    test('SÍ notifica si el id es igual pero el rol cambió', () {
      var notificado = false;
      vm.addListener(() => notificado = true);

      final mismoIdOtroRol = AgentePolicia(
        id: 'comando-1',
        nombre: 'Oficial de Prueba',
        rol: Rol.OPERADOR_CAI, // rol distinto
        estadoAgente: EstadoAgente.DISPONIBLE,
      );

      vm.actualizarUsuario(mismoIdOtroRol);

      expect(notificado, isTrue);
      expect(vm.currentUser.rol, Rol.OPERADOR_CAI);
    });
  });

  group('getters filtrados por rol', () {
    test('incidentosReportados solo incluye estado CREADO', () {
      vm.delegarACai('inc-001', 'cai-007');
      // El único incidente mock pasó a DERIVADO_A_CAI -> ya no aparece aquí.
      expect(vm.incidentosReportados, isEmpty);
    });

    test('incidentosDelegados incluye todo lo que no sea CREADO', () {
      expect(vm.incidentosDelegados, isEmpty); // inicialmente todo es CREADO
      vm.delegarACai('inc-001', 'cai-007');
      expect(vm.incidentosDelegados, hasLength(1));
    });

    test('pendientesPorAsignar filtra por CAI del currentUser y estado DERIVADO_A_CAI',
        () {
      vm.delegarACai('inc-001', 'CAI San Francisco'); // coincide con comando.cai
      expect(vm.pendientesPorAsignar, hasLength(1));
    });

    test('pendientesPorAsignar vacío si el CAI no coincide', () {
      vm.delegarACai('inc-001', 'Otro CAI');
      expect(vm.pendientesPorAsignar, isEmpty);
    });

    test('misAsignaciones filtra por agenteId == currentUser.id', () {
      final agente = AgentePolicia(
        id: 'agente-001',
        nombre: 'Pedro',
        rol: Rol.AGENTE,
        estadoAgente: EstadoAgente.DISPONIBLE,
      );
      final vmAgente = IncidenteViewModel(currentUser: agente);

      vmAgente.asignarAgente('inc-001', 'agente-001');

      expect(vmAgente.misAsignaciones, hasLength(1));
    });
  });

  group('acciones de negocio (mock en memoria)', () {
    test('crearReporte agrega un nuevo incidente en estado CREADO', () {
      final tipo = TipoIncidente(
        id: '99',
        titulo: 'Robo',
        descripcion: 'Robo a mano armada',
        icono: vm.catalogTypes.first.icono,
        color: vm.catalogTypes.first.color,
      );

      final cantidadInicial = vm.incidentosReportados.length;
      vm.crearReporte(tipo);

      expect(vm.incidentosReportados.length, cantidadInicial + 1);
    });

    test('delegarACai cambia el estado a DERIVADO_A_CAI y asigna caiId', () {
      vm.delegarACai('inc-001', 'cai-007');

      final incidente = vm.incidentosDelegados.first;
      expect(incidente.estado, EstadoIncidente.DERIVADO_A_CAI);
      expect(incidente.caiId, 'cai-007');
    });

    test('asignarAgente cambia el estado a AGENTE_ASIGNADO y asigna agenteId',
        () {
      vm.asignarAgente('inc-001', 'agente-001');

      final incidente = vm.incidentosDelegados.first;
      expect(incidente.estado, EstadoIncidente.AGENTE_ASIGNADO);
      expect(incidente.agenteId, 'agente-001');
    });

    test('completarIncidente cambia el estado a FINALIZADO', () {
      vm.completarIncidente('inc-001');

      final incidente = vm.incidentosDelegados.first;
      expect(incidente.estado, EstadoIncidente.FINALIZADO);
    });

    test('acción sobre un id inexistente no lanza y no modifica nada', () {
      expect(() => vm.delegarACai('id-inexistente', 'cai-x'),
          returnsNormally);
      expect(() => vm.asignarAgente('id-inexistente', 'agente-x'),
          returnsNormally);
      expect(() => vm.completarIncidente('id-inexistente'), returnsNormally);

      // El incidente original sigue intacto en CREADO.
      expect(vm.incidentosReportados, hasLength(1));
    });

    test('cada acción de negocio notifica a los listeners', () {
      var notificaciones = 0;
      vm.addListener(() => notificaciones++);

      vm.delegarACai('inc-001', 'cai-007');
      expect(notificaciones, 1);

      vm.asignarAgente('inc-001', 'agente-001');
      expect(notificaciones, 2);

      vm.completarIncidente('inc-001');
      expect(notificaciones, 3);
    });
  });

  group('fetchIncidentes (placeholder de carga)', () {
    test('alterna isLoading true -> false sin lanzar', () async {
      final estados = <bool>[];
      vm.addListener(() => estados.add(vm.isLoading));

      await vm.fetchIncidentes();

      expect(estados, contains(true));
      expect(vm.isLoading, isFalse);
    });
  });
}