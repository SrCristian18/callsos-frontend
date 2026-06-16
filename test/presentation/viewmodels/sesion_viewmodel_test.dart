import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:CallSos/data/models/auth_result.dart';
import 'package:CallSos/data/models/enums/rol.dart';
import 'package:CallSos/data/services/api_exception.dart';
import 'package:CallSos/data/services/auth_service.dart';
import 'package:CallSos/data/services/secure_storage.dart';
import 'package:CallSos/presentation/viewmodels/sesion_viewmodel.dart';

class MockAuthService extends Mock implements IAuthService {}

/// Almacenamiento en memoria para tests (ver [ISecureStorage]).
class FakeSecureStorage implements ISecureStorage {
  final Map<String, String> _datos = {};

  @override
  Future<String?> read(String key) async => _datos[key];

  @override
  Future<void> write(String key, String value) async => _datos[key] = value;

  @override
  Future<void> delete(String key) async => _datos.remove(key);

  bool get estaVacio => _datos.isEmpty;
}

/// Construye un JWT `header.payload.signature` con el [payload] dado.
/// La firma es un valor cualquiera — SesionViewModel no la valida (eso es
/// responsabilidad exclusiva del backend); solo decodifica el payload para
/// leer `exp`.
String _crearJwt(Map<String, dynamic> payload) {
  String segmento(Map<String, dynamic> data) =>
      base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');

  final header = segmento({'alg': 'HS256', 'typ': 'JWT'});
  final body = segmento(payload);
  return '$header.$body.firma-falsa';
}

/// `exp` en segundos desde epoch, [horas] en el futuro (o pasado si negativo).
int _expEnHoras(int horas) =>
    DateTime.now().toUtc().add(Duration(hours: horas)).millisecondsSinceEpoch ~/ 1000;

void main() {
  late MockAuthService authService;
  late FakeSecureStorage storage;
  late SesionViewModel sesion;

  setUp(() {
    authService = MockAuthService();
    storage = FakeSecureStorage();
    sesion = SesionViewModel(authService: authService, storage: storage);
  });

  group('restaurarSesion', () {
    test('sin datos guardados -> no autenticado, isLoading false al terminar', () async {
      await sesion.restaurarSesion();

      expect(sesion.isAuthenticated, isFalse);
      expect(sesion.isLoading, isFalse);
      expect(sesion.token, isNull);
      expect(sesion.actorId, isNull);
      expect(sesion.rol, isNull);
    });

    test('token válido (exp futuro) y datos completos -> restaura la sesión', () async {
      final jwt = _crearJwt({'sub': 'agente-001', 'rol': 'AGENTE', 'exp': _expEnHoras(24)});
      await storage.write('callsos_jwt_token', jwt);
      await storage.write('callsos_actor_id', 'agente-001');
      await storage.write('callsos_rol', 'AGENTE');

      await sesion.restaurarSesion();

      expect(sesion.isAuthenticated, isTrue);
      expect(sesion.token, jwt);
      expect(sesion.actorId, 'agente-001');
      expect(sesion.rol, Rol.AGENTE);
    });

    test('token expirado -> no autentica y limpia el storage', () async {
      final jwt = _crearJwt({'sub': 'agente-001', 'rol': 'AGENTE', 'exp': _expEnHoras(-1)});
      await storage.write('callsos_jwt_token', jwt);
      await storage.write('callsos_actor_id', 'agente-001');
      await storage.write('callsos_rol', 'AGENTE');

      await sesion.restaurarSesion();

      expect(sesion.isAuthenticated, isFalse);
      expect(storage.estaVacio, isTrue);
    });

    test('datos incompletos (falta rol guardado) -> no autentica y limpia', () async {
      final jwt = _crearJwt({'sub': 'agente-001', 'rol': 'AGENTE', 'exp': _expEnHoras(24)});
      await storage.write('callsos_jwt_token', jwt);
      await storage.write('callsos_actor_id', 'agente-001');
      // Falta 'callsos_rol' a propósito.

      await sesion.restaurarSesion();

      expect(sesion.isAuthenticated, isFalse);
      expect(storage.estaVacio, isTrue);
    });

    test('token malformado (no tiene 3 segmentos) -> no autentica', () async {
      await storage.write('callsos_jwt_token', 'esto-no-es-un-jwt');
      await storage.write('callsos_actor_id', 'agente-001');
      await storage.write('callsos_rol', 'AGENTE');

      await sesion.restaurarSesion();

      expect(sesion.isAuthenticated, isFalse);
      expect(storage.estaVacio, isTrue);
    });
  });

  group('login', () {
    test('login exitoso actualiza el estado y persiste en storage', () async {
      when(() => authService.login(username: 'pedro.agente', password: 'password123'))
          .thenAnswer((_) async => const AuthResult(
                token: 'jwt-de-prueba',
                actorId: 'agente-001',
                rol: Rol.AGENTE,
              ));

      final exito = await sesion.login(username: 'pedro.agente', password: 'password123');

      expect(exito, isTrue);
      expect(sesion.isAuthenticated, isTrue);
      expect(sesion.token, 'jwt-de-prueba');
      expect(sesion.actorId, 'agente-001');
      expect(sesion.rol, Rol.AGENTE);
      expect(sesion.errorMessage, isNull);
      expect(sesion.isLoading, isFalse);

      // Persistido para sobrevivir reinicios (criterio de terminado F.0.4).
      expect(await storage.read('callsos_jwt_token'), 'jwt-de-prueba');
      expect(await storage.read('callsos_actor_id'), 'agente-001');
      expect(await storage.read('callsos_rol'), 'AGENTE');
    });

    test('login fallido (credenciales inválidas) -> errorMessage seteado, no autenticado', () async {
      when(() => authService.login(username: 'pedro.agente', password: 'mala-clave'))
          .thenThrow(const ApiException(
        type: ApiExceptionType.unauthorized,
        statusCode: 401,
        message: 'Usuario o contraseña incorrectos.',
      ));

      final exito = await sesion.login(username: 'pedro.agente', password: 'mala-clave');

      expect(exito, isFalse);
      expect(sesion.isAuthenticated, isFalse);
      expect(sesion.errorMessage, 'Usuario o contraseña incorrectos.');
      expect(sesion.isLoading, isFalse);
      expect(storage.estaVacio, isTrue);
    });

    test('un login fallido NO cierra una sesión previa válida', () async {
      // Sesión previa válida.
      when(() => authService.login(username: 'pedro.agente', password: 'password123'))
          .thenAnswer((_) async => const AuthResult(
                token: 'jwt-valido',
                actorId: 'agente-001',
                rol: Rol.AGENTE,
              ));
      await sesion.login(username: 'pedro.agente', password: 'password123');
      expect(sesion.isAuthenticated, isTrue);

      // Reintento (ej. desde otra pantalla) que falla por timeout.
      when(() => authService.login(username: 'pedro.agente', password: 'password123'))
          .thenThrow(const ApiException(
        type: ApiExceptionType.timeout,
        message: 'El servidor tardó demasiado en responder.',
      ));
      final exito = await sesion.login(username: 'pedro.agente', password: 'password123');

      expect(exito, isFalse);
      expect(sesion.errorMessage, isNotNull);
      // La sesión anterior se conserva intacta:
      expect(sesion.isAuthenticated, isTrue);
      expect(sesion.token, 'jwt-valido');
      expect(sesion.actorId, 'agente-001');
      expect(sesion.rol, Rol.AGENTE);
    });
  });

  group('logout', () {
    test('limpia el estado en memoria y el storage', () async {
      when(() => authService.login(username: 'pedro.agente', password: 'password123'))
          .thenAnswer((_) async => const AuthResult(
                token: 'jwt-valido',
                actorId: 'agente-001',
                rol: Rol.AGENTE,
              ));
      await sesion.login(username: 'pedro.agente', password: 'password123');
      expect(sesion.isAuthenticated, isTrue);

      await sesion.logout();

      expect(sesion.isAuthenticated, isFalse);
      expect(sesion.token, isNull);
      expect(sesion.actorId, isNull);
      expect(sesion.rol, isNull);
      expect(storage.estaVacio, isTrue);
    });
  });

  group('nombrePlaceholder', () {
    test('cadena vacía si no hay sesión activa', () {
      expect(sesion.nombrePlaceholder, isEmpty);
    });

    test('incluye la etiqueta del rol y un fragmento del actorId si hay sesión', () async {
      when(() => authService.login(username: 'pedro.agente', password: 'password123'))
          .thenAnswer((_) async => const AuthResult(
                token: 'jwt-valido',
                actorId: 'agente-001-test',
                rol: Rol.AGENTE,
              ));
      await sesion.login(username: 'pedro.agente', password: 'password123');

      expect(sesion.nombrePlaceholder, contains(Rol.AGENTE.etiqueta));
      expect(sesion.nombrePlaceholder, contains('agente-0')); // primeros 8 chars
    });
  });
}