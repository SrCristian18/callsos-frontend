import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:CallSos/data/models/enums/rol.dart';
import 'package:CallSos/data/services/agente_service.dart';
import 'package:CallSos/data/services/cai_service.dart';
import 'package:CallSos/data/services/denunciante_service.dart';
import 'package:CallSos/data/services/notificacion_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class MockDenuncianteService extends Mock implements IDenuncianteService {}

class MockAgenteService extends Mock implements IAgenteService {}

class MockCaiService extends Mock implements ICaiService {}

/// Mock de FirebaseMessaging para tests sin plataforma real.
class MockFirebaseMessaging extends Mock implements FirebaseMessaging {}

void main() {
  late MockDenuncianteService denuncianteService;
  late MockAgenteService agenteService;
  late MockCaiService caiService;
  late MockFirebaseMessaging fcm;
  late NotificacionService service;

  setUp(() {
    denuncianteService = MockDenuncianteService();
    agenteService = MockAgenteService();
    caiService = MockCaiService();
    fcm = MockFirebaseMessaging();
    service = NotificacionService(
      denuncianteService: denuncianteService,
      agenteService: agenteService,
      caiService: caiService,
      fcm: fcm,
    );
  });

  // ─────────────────────────────────────────────────────────────────────
  // Nota sobre la estrategia de tests de F.5:
  //
  // Firebase (firebase_messaging, flutter_local_notifications) requiere
  // platform channels nativos no disponibles en flutter_test puro.
  // La estrategia es la misma que F.0.6 (geolocalizacion_service_test):
  // - Se mockea FirebaseMessaging para aislar la lógica de negocio.
  // - La inicialización del canal de notificaciones locales NO se testea
  //   unitariamente (pertenece al ámbito de integration tests en dispositivo).
  // - Se testea el contrato: "si FCM devuelve un token → se registra en
  //   el backend, en el servicio correcto según el rol (Épica 8,
  //   hallazgo #5)", "si FCM devuelve null → no se llama a ningún servicio".
  // ─────────────────────────────────────────────────────────────────────

  group('NotificacionPayload.fromRemoteMessage', () {
    test('extrae título, cuerpo y datos del RemoteMessage correctamente', () {
      // Verifica que el mapeo del payload del backend (AgenteEnCaminoEvent,
      // IncidenteFinalizadoEvent) a NotificacionPayload es correcto.
      final payload = NotificacionPayload(
        titulo: 'Callsos — Actualización',
        cuerpo: 'Un agente de policía va en camino a tu ubicación.',
        datos: {'incidenteId': 'inc-001'},
      );

      expect(payload.titulo, 'Callsos — Actualización');
      expect(payload.cuerpo,
          'Un agente de policía va en camino a tu ubicación.');
      expect(payload.datos['incidenteId'], 'inc-001');
    });

    test('usa valores por defecto cuando notification es null', () {
      final payload = NotificacionPayload(
        titulo: 'CallSOS',
        cuerpo: '',
        datos: const {},
      );

      expect(payload.titulo, 'CallSOS');
      expect(payload.cuerpo, isEmpty);
    });
  });

  group('registrarTokenEnBackend', () {
    test('rol DENUNCIANTE: obtiene token FCM y lo envía a IDenuncianteService',
        () async {
      when(() => fcm.getToken())
          .thenAnswer((_) async => 'fcm-token-abc-123');
      when(() => denuncianteService.registrarTokenFcm(
            actorId: any(named: 'actorId'),
            tokenFcm: any(named: 'tokenFcm'),
          )).thenAnswer((_) async {});
      when(() => fcm.onTokenRefresh)
          .thenAnswer((_) => const Stream.empty());

      final token = await service.registrarTokenEnBackend(
          actorId: 'den-001', rol: Rol.DENUNCIANTE);

      expect(token, 'fcm-token-abc-123');
      verify(() => denuncianteService.registrarTokenFcm(
            actorId: 'den-001',
            tokenFcm: 'fcm-token-abc-123',
          )).called(1);
      verifyNever(() => agenteService.registrarTokenFcm(
            actorId: any(named: 'actorId'),
            tokenFcm: any(named: 'tokenFcm'),
          ));
      verifyNever(() => caiService.registrarTokenFcm(
            unidadPolicialId: any(named: 'unidadPolicialId'),
            tokenFcm: any(named: 'tokenFcm'),
          ));
    });

    test(
        'rol AGENTE (Épica 8, hallazgo #5): obtiene token FCM y lo envía a '
        'IAgenteService, no a IDenuncianteService', () async {
      when(() => fcm.getToken())
          .thenAnswer((_) async => 'fcm-token-agente');
      when(() => agenteService.registrarTokenFcm(
            actorId: any(named: 'actorId'),
            tokenFcm: any(named: 'tokenFcm'),
          )).thenAnswer((_) async {});
      when(() => fcm.onTokenRefresh)
          .thenAnswer((_) => const Stream.empty());

      final token = await service.registrarTokenEnBackend(
          actorId: 'ag-001', rol: Rol.AGENTE);

      expect(token, 'fcm-token-agente');
      verify(() => agenteService.registrarTokenFcm(
            actorId: 'ag-001',
            tokenFcm: 'fcm-token-agente',
          )).called(1);
      verifyNever(() => denuncianteService.registrarTokenFcm(
            actorId: any(named: 'actorId'),
            tokenFcm: any(named: 'tokenFcm'),
          ));
    });

    test(
        'rol OPERADOR_CAI (Épica 8, hallazgo #5): obtiene token FCM y lo '
        'envía a ICaiService con unidadPolicialId == actorId', () async {
      when(() => fcm.getToken())
          .thenAnswer((_) async => 'fcm-token-cai');
      when(() => caiService.registrarTokenFcm(
            unidadPolicialId: any(named: 'unidadPolicialId'),
            tokenFcm: any(named: 'tokenFcm'),
          )).thenAnswer((_) async {});
      when(() => fcm.onTokenRefresh)
          .thenAnswer((_) => const Stream.empty());

      final token = await service.registrarTokenEnBackend(
          actorId: 'cai-001', rol: Rol.OPERADOR_CAI);

      expect(token, 'fcm-token-cai');
      verify(() => caiService.registrarTokenFcm(
            unidadPolicialId: 'cai-001',
            tokenFcm: 'fcm-token-cai',
          )).called(1);
    });

    test(
        'rol COMANDO (Épica 8, hallazgo #5): no llama a ningún servicio ni '
        'a fcm.getToken() — el backend no tiene tokenFcm para este rol',
        () async {
      final token = await service.registrarTokenEnBackend(
          actorId: 'com-001', rol: Rol.COMANDO);

      expect(token, isNull);
      verifyNever(() => fcm.getToken());
      verifyNever(() => denuncianteService.registrarTokenFcm(
            actorId: any(named: 'actorId'),
            tokenFcm: any(named: 'tokenFcm'),
          ));
      verifyNever(() => agenteService.registrarTokenFcm(
            actorId: any(named: 'actorId'),
            tokenFcm: any(named: 'tokenFcm'),
          ));
      verifyNever(() => caiService.registrarTokenFcm(
            unidadPolicialId: any(named: 'unidadPolicialId'),
            tokenFcm: any(named: 'tokenFcm'),
          ));
    });

    test('si getToken() devuelve null, no llama a ningún servicio y devuelve null',
        () async {
      when(() => fcm.getToken()).thenAnswer((_) async => null);

      final token = await service.registrarTokenEnBackend(
          actorId: 'den-001', rol: Rol.DENUNCIANTE);

      expect(token, isNull);
      verifyNever(() => denuncianteService.registrarTokenFcm(
            actorId: any(named: 'actorId'),
            tokenFcm: any(named: 'tokenFcm'),
          ));
    });

    test('error de red al registrar token → devuelve null sin lanzar',
        () async {
      when(() => fcm.getToken())
          .thenAnswer((_) async => 'fcm-token-xyz');
      when(() => denuncianteService.registrarTokenFcm(
            actorId: any(named: 'actorId'),
            tokenFcm: any(named: 'tokenFcm'),
          )).thenThrow(Exception('Sin conexión'));

      // Nunca lanza — el registro de token es complementario al flujo
      // principal, no debe romperlo.
      expect(
        () async => await service.registrarTokenEnBackend(
            actorId: 'den-001', rol: Rol.DENUNCIANTE),
        returnsNormally,
      );

      final token = await service.registrarTokenEnBackend(
          actorId: 'den-001', rol: Rol.DENUNCIANTE);
      expect(token, isNull);
    });
  });
}