import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../data/models/enums/rol.dart';
import '../../data/services/api_exception.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/secure_storage.dart';
import '../../data/services/token_provider.dart';

/// Estado global de sesión: token JWT, identidad del actor autenticado, y
/// operaciones de login/logout/restauración.
///
/// F.0.4 — Gestión de sesión.
///
/// Responsabilidades:
/// - Mantener `{token, actorId, rol}` tras un login exitoso
///   (`POST /auth/login` vía [IAuthService]).
/// - Persistir el JWT (y `actorId`/`rol`) en almacenamiento seguro
///   ([ISecureStorage]) para sobrevivir reinicios de la app.
/// - [restaurarSesion]: al iniciar la app, leer el storage y, si el JWT
///   sigue vigente (claim `exp` no expirado), restaurar la sesión sin pedir
///   login de nuevo.
/// - Implementar [ITokenProvider] para que [ApiClient] (F.0.3) inyecte
///   automáticamente `Authorization: Bearer <token>` en cada petición.
///
/// ## Cableado en `AppProviders` (ver F.0.4)
/// ```dart
/// final apiClient = ApiClient();
/// final sesion = SesionViewModel(authService: AuthService(apiClient))
///   ..restaurarSesion(); // dispara la restauración sin bloquear el build
/// apiClient.tokenProvider = sesion;
/// ```
///
/// ## Placeholder de "nombre" (decisión registrada en este chat)
/// El backend (`AuthResponse`) NO devuelve `nombre` del usuario — solo
/// `{token, actorId, rol}`. Mientras esa deuda de backend no se resuelva
/// (ver F.0.7), la UI debe usar [nombrePlaceholder] en los lugares donde
/// antes se mostraba `AgentePolicia.nombre`.
class SesionViewModel extends ChangeNotifier implements ITokenProvider {
  final IAuthService _authService;
  final ISecureStorage _storage;

  SesionViewModel({
    required IAuthService authService,
    ISecureStorage? storage,
  })  : _authService = authService,
        _storage = storage ?? const SecureStorageAdapter();

  // ───────────────────────────────────────────────────────────────────────
  // Claves de almacenamiento seguro
  // ───────────────────────────────────────────────────────────────────────

  static const _kTokenKey = 'callsos_jwt_token';
  static const _kActorIdKey = 'callsos_actor_id';
  static const _kRolKey = 'callsos_rol';

  // ───────────────────────────────────────────────────────────────────────
  // Estado
  // ───────────────────────────────────────────────────────────────────────

  String? _token;
  String? _actorId;
  Rol? _rol;

  /// `true` mientras se ejecuta [login] o [restaurarSesion].
  ///
  /// `AppProviders` inicializa la sesión con
  /// `SesionViewModel(...)..restaurarSesion()`, por lo que [isLoading]
  /// arranca en `true` desde el primer frame — la UI (F.0.5) debe mostrar
  /// un splash/loading mientras esto sea `true`, para no parpadear hacia
  /// una pantalla de login y luego saltar a la home si había sesión válida.
  bool _isLoading = true;

  String? _errorMessage;

  /// JWT actual, o `null` si no hay sesión activa.
  ///
  /// Implementación de [ITokenProvider] — usado por [ApiClient] para el
  /// header `Authorization: Bearer <token>`.
  @override
  String? get token => _token;

  /// Id de negocio del actor autenticado (denunciante/agente/unidad),
  /// extraído de `AuthResponse.actorId`.
  String? get actorId => _actorId;

  /// Rol del actor autenticado (ver [Rol]).
  Rol? get rol => _rol;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  /// `true` si hay una sesión válida (token + actorId + rol presentes y el
  /// token no expirado).
  bool get isAuthenticated => _token != null && _actorId != null && _rol != null;

  /// Placeholder de presentación para el "nombre" del usuario.
  ///
  /// DEUDA DE BACKEND (F.0.7): `AuthResponse` no incluye `nombre`. Mientras
  /// no exista un endpoint de perfil, se muestra la etiqueta del rol más un
  /// fragmento del `actorId` (ej. "Agente de Policía • agente-0").
  ///
  /// Devuelve cadena vacía si no hay sesión activa.
  String get nombrePlaceholder {
    if (!isAuthenticated) return '';
    final id = _actorId!;
    final idCorto = id.length > 8 ? id.substring(0, 8) : id;
    return '${_rol!.etiqueta} • $idCorto';
  }

  // ───────────────────────────────────────────────────────────────────────
  // Operaciones
  // ───────────────────────────────────────────────────────────────────────

  /// Intenta restaurar una sesión previa desde almacenamiento seguro.
  ///
  /// Debe llamarse una vez al iniciar la app (ver cableado en
  /// `AppProviders`). Si hay un JWT guardado y su claim `exp` aún no venció,
  /// restaura `{token, actorId, rol}` sin requerir login. En caso contrario
  /// (no hay datos, están incompletos, el JWT expiró, o no se puede
  /// decodificar), limpia el storage y deja la sesión como "no autenticada".
  ///
  /// Nunca lanza: cualquier error de lectura/parseo se trata como "sin
  /// sesión válida".
  Future<void> restaurarSesion() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _storage.read(_kTokenKey);
      final actorId = await _storage.read(_kActorIdKey);
      final rolGuardado = await _storage.read(_kRolKey);

      final datosCompletos = token != null && actorId != null && rolGuardado != null;

      if (datosCompletos && !_tokenExpirado(token)) {
        _token = token;
        _actorId = actorId;
        _rol = rolFromJson(rolGuardado);
      } else {
        await _limpiarStorage();
        _limpiarEstado();
      }
    } catch (_) {
      // Cualquier error de lectura/parseo -> tratar como "sin sesión".
      await _limpiarStorage();
      _limpiarEstado();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Autentica con `username`/`password` (`POST /auth/login`).
  ///
  /// Si es exitoso: actualiza `{token, actorId, rol}`, los persiste en
  /// almacenamiento seguro, y devuelve `true`. Si falla: deja [errorMessage]
  /// con un texto apto para mostrar en el formulario (ver
  /// [AuthService.login] — credenciales inválidas, timeout, sin conexión,
  /// etc.) y devuelve `false`. Nunca lanza.
  ///
  /// Un intento fallido NO afecta una sesión previa existente: si ya había
  /// `{token, actorId, rol}` válidos (ej. el usuario reintenta login desde
  /// una pantalla que no debería estar viendo, o falla por timeout), esos
  /// datos se conservan intactos — solo se actualiza [errorMessage].
  Future<bool> login({required String username, required String password}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final resultado = await _authService.login(username: username, password: password);

      _token = resultado.token;
      _actorId = resultado.actorId;
      _rol = resultado.rol;

      await _storage.write(_kTokenKey, resultado.token);
      await _storage.write(_kActorIdKey, resultado.actorId);
      await _storage.write(_kRolKey, resultado.rol.toJson());

      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage = 'Ocurrió un error inesperado. Inténtalo de nuevo.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Cierra la sesión: limpia el estado en memoria y el almacenamiento
  /// seguro.
  Future<void> logout() async {
    await _limpiarStorage();
    _limpiarEstado();
    _errorMessage = null;
    notifyListeners();
  }

  // ───────────────────────────────────────────────────────────────────────
  // Helpers privados
  // ───────────────────────────────────────────────────────────────────────

  void _limpiarEstado() {
    _token = null;
    _actorId = null;
    _rol = null;
  }

  Future<void> _limpiarStorage() async {
    await _storage.delete(_kTokenKey);
    await _storage.delete(_kActorIdKey);
    await _storage.delete(_kRolKey);
  }

  /// `true` si el JWT ya expiró (o no se puede determinar su vigencia).
  ///
  /// Decodifica el payload del JWT (segundo segmento, base64url) SIN
  /// verificar la firma — la verificación de firma es responsabilidad
  /// exclusiva del backend; aquí solo se usa `exp` para decidir si vale la
  /// pena seguir usando el token localmente o pedir login de nuevo.
  ///
  /// Por seguridad, cualquier token sin `exp` o no decodificable se trata
  /// como expirado.
  static bool _tokenExpirado(String token) {
    final payload = _decodificarPayloadJwt(token);
    if (payload == null) return true;

    final exp = payload['exp'];
    if (exp is! int) return true;

    final expiracion = DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
    return DateTime.now().toUtc().isAfter(expiracion);
  }

  /// Decodifica el payload (claims) de un JWT `header.payload.signature`.
  ///
  /// Devuelve `null` si el token no tiene el formato esperado o el payload
  /// no es JSON válido.
  static Map<String, dynamic>? _decodificarPayloadJwt(String token) {
    final partes = token.split('.');
    if (partes.length != 3) return null;

    try {
      // El payload de un JWT está en base64url SIN padding ('='); 'normalize'
      // agrega el padding que requiere dart:convert para decodificar.
      final normalizado = base64Url.normalize(partes[1]);
      final decodificado = utf8.decode(base64Url.decode(normalizado));
      final json = jsonDecode(decodificado);
      return json is Map<String, dynamic> ? json : null;
    } catch (_) {
      return null;
    }
  }
}