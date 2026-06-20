import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:CallSos/data/services/permiso_notificacion_service.dart';

class MockFirebaseMessaging extends Mock implements FirebaseMessaging {}

class FakeNotificationSettings extends Fake
    implements NotificationSettings {
  @override
  final AuthorizationStatus authorizationStatus;

  FakeNotificationSettings(this.authorizationStatus);

  // Valores por defecto para los demás campos requeridos por la interfaz
  @override
  AppleNotificationSetting get alert => AppleNotificationSetting.notSupported;
  @override
  AppleNotificationSetting get announcement =>
      AppleNotificationSetting.notSupported;
  @override
  AppleNotificationSetting get badge => AppleNotificationSetting.notSupported;
  @override
  AppleNotificationSetting get carPlay =>
      AppleNotificationSetting.notSupported;
  @override
  AppleNotificationSetting get criticalAlert =>
      AppleNotificationSetting.notSupported;
  @override
  AppleNotificationSetting get sound => AppleNotificationSetting.notSupported;
  @override
  AppleShowPreviewSetting get showPreviews =>
      AppleShowPreviewSetting.notSupported;
  @override
  AppleNotificationSetting get timeSensitive =>
      AppleNotificationSetting.notSupported;
  @override
  AndroidNotificationPriority get priority =>
      AndroidNotificationPriority.defaultPriority;
}

void main() {
  late MockFirebaseMessaging fcm;
  late PermisoNotificacionService service;

  setUp(() {
    fcm = MockFirebaseMessaging();
    service = PermisoNotificacionService(fcm: fcm);
  });

  // ── verificarEstado ─────────────────────────────────────────────────

  group('verificarEstado', () {
    test('devuelve concedido cuando el estado es authorized', () async {
      when(() => fcm.getNotificationSettings()).thenAnswer(
        (_) async => FakeNotificationSettings(AuthorizationStatus.authorized),
      );

      final resultado = await service.verificarEstado();
      expect(resultado, PermisoNotificacionResultado.concedido);
    });

    test('devuelve concedido cuando el estado es provisional (iOS)', () async {
      when(() => fcm.getNotificationSettings()).thenAnswer(
        (_) async =>
            FakeNotificationSettings(AuthorizationStatus.provisional),
      );

      final resultado = await service.verificarEstado();
      expect(resultado, PermisoNotificacionResultado.concedido);
    });

    test('devuelve denegado cuando el estado es denied', () async {
      when(() => fcm.getNotificationSettings()).thenAnswer(
        (_) async => FakeNotificationSettings(AuthorizationStatus.denied),
      );

      final resultado = await service.verificarEstado();
      expect(resultado, PermisoNotificacionResultado.denegado);
    });

    test('devuelve indeterminado cuando el estado es notDetermined', () async {
      when(() => fcm.getNotificationSettings()).thenAnswer(
        (_) async =>
            FakeNotificationSettings(AuthorizationStatus.notDetermined),
      );

      final resultado = await service.verificarEstado();
      expect(resultado, PermisoNotificacionResultado.indeterminado);
    });

    test('devuelve indeterminado si getNotificationSettings lanza', () async {
      when(() => fcm.getNotificationSettings())
          .thenThrow(Exception('Platform error'));

      final resultado = await service.verificarEstado();
      expect(resultado, PermisoNotificacionResultado.indeterminado);
    });
  });

  // ── solicitarPermiso ────────────────────────────────────────────────

  group('solicitarPermiso', () {
    test('concedido en Android < 13 o cuando usuario acepta', () async {
      when(() => fcm.requestPermission(
            alert: any(named: 'alert'),
            badge: any(named: 'badge'),
            sound: any(named: 'sound'),
            provisional: any(named: 'provisional'),
          )).thenAnswer(
        (_) async => FakeNotificationSettings(AuthorizationStatus.authorized),
      );

      final resultado = await service.solicitarPermiso();
      expect(resultado, PermisoNotificacionResultado.concedido);
    });

    test('denegado cuando el usuario rechaza el diálogo', () async {
      when(() => fcm.requestPermission(
            alert: any(named: 'alert'),
            badge: any(named: 'badge'),
            sound: any(named: 'sound'),
            provisional: any(named: 'provisional'),
          )).thenAnswer(
        (_) async => FakeNotificationSettings(AuthorizationStatus.denied),
      );

      final resultado = await service.solicitarPermiso();
      expect(resultado, PermisoNotificacionResultado.denegado);
    });

    test('indeterminado si requestPermission lanza', () async {
      when(() => fcm.requestPermission(
            alert: any(named: 'alert'),
            badge: any(named: 'badge'),
            sound: any(named: 'sound'),
            provisional: any(named: 'provisional'),
          )).thenThrow(Exception('No Firebase'));

      final resultado = await service.solicitarPermiso();
      expect(resultado, PermisoNotificacionResultado.indeterminado);
    });
  });
}