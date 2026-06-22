import 'package:geolocator/geolocator.dart';

import '../models/valueobject/ubicacion.dart';

/// Resultado de [IGeolocalizacionService.solicitarPermiso].
///
/// F.0.6 — Servicio de geolocalización.
enum PermisoGpsResultado {
  /// GPS habilitado y permiso concedido — se puede obtener posición.
  concedido,

  /// El usuario denegó el permiso pero puede cambiarlo desde ajustes.
  denegado,

  /// El usuario denegó permanentemente (Android: "No preguntar de nuevo" /
  /// iOS: "Never allow"). Solo se puede resolver llevando al usuario a
  /// ajustes del sistema ([Geolocator.openAppSettings]).
  denegadoPermanentemente,

  /// El GPS/servicio de ubicación está desactivado en el dispositivo.
  servicioDesactivado,
}

/// Servicio de geolocalización — abstracción sobre `geolocator`.
///
/// F.0.6 — Servicio de geolocalización.
///
/// Esta interfaz existe para:
/// 1. Desacoplar la UI y los ViewModels de `geolocator` directamente.
/// 2. Permitir mocks en tests sin acceso a plataforma real (F.7).
///
/// Usos previstos:
/// - F.1 ([HomeDenuncianteView]): [obtenerPosicionActual] al crear un
///   incidente (botón de pánico → `CrearIncidenteRequest.ubicacion`).
/// - F.3 ([TrackingView]): [streamPosicion] para que el agente emita
///   su posición en tiempo real al canal STOMP del backend.
abstract class IGeolocalizacionService {
  /// Verifica el estado del GPS y solicita permiso si es necesario.
  ///
  /// Debe llamarse ANTES de [obtenerPosicionActual] o [streamPosicion].
  /// Retorna un [PermisoGpsResultado] que la UI debe manejar:
  /// - [PermisoGpsResultado.concedido] → proceder normalmente.
  /// - Otros → mostrar mensaje y/o llevar a ajustes.
  Future<PermisoGpsResultado> solicitarPermiso();

  /// Obtiene la posición GPS actual una sola vez.
  ///
  /// Usa [LocationAccuracy.high] (GPS fino) — necesario para que el
  /// backend pueda calcular el CAI más cercano con Haversine.
  ///
  /// Lanza [GeolocalizacionException] si:
  /// - El permiso no fue concedido (llamar [solicitarPermiso] antes).
  /// - El GPS está desactivado.
  /// - Timeout superado sin señal GPS (puede ocurrir en interiores).
  /// [precisionAlta]: si `true` (por defecto) usa [LocationAccuracy.high]
  /// con timeout de 15s — para la creación de incidentes donde las
  /// coordenadas se envían al backend. Si `false`, usa
  /// [LocationAccuracy.medium] con timeout de 30s — para mostrar la
  /// posición del denunciante en el mapa de tracking.
  Future<Ubicacion> obtenerPosicionActual({bool precisionAlta = true});

  /// Stream continuo de posiciones GPS para el tracking en tiempo real.
  ///
  /// Emite una nueva [Ubicacion] cada vez que la posición cambia más de
  /// [distanciaFiltroMetros] metros (por defecto 10 m) — evita saturar
  /// el canal STOMP con actualizaciones innecesarias cuando el agente
  /// está parado.
  ///
  /// El stream debe cancelarse ([StreamSubscription.cancel]) cuando el
  /// agente finaliza la atención o cierra [TrackingView] (F.3).
  Stream<Ubicacion> streamPosicion({double distanciaFiltroMetros = 10.0});
}

/// Excepción de dominio para errores de geolocalización.
///
/// La UI solo necesita conocer este tipo — nunca un error de `geolocator`
/// o de plataforma directamente.
class GeolocalizacionException implements Exception {
  final String message;
  const GeolocalizacionException(this.message);

  @override
  String toString() => 'GeolocalizacionException: $message';
}

/// Implementación de [IGeolocalizacionService] sobre `geolocator`.
class GeolocalizacionService implements IGeolocalizacionService {
  @override
  Future<PermisoGpsResultado> solicitarPermiso() async {
    // 1. Verificar si el servicio de ubicación está habilitado.
    final servicioHabilitado = await Geolocator.isLocationServiceEnabled();
    if (!servicioHabilitado) {
      return PermisoGpsResultado.servicioDesactivado;
    }

    // 2. Verificar/solicitar permiso de ubicación.
    var permiso = await Geolocator.checkPermission();

    if (permiso == LocationPermission.denied) {
      // Primera solicitud al sistema — muestra el diálogo nativo de permisos.
      permiso = await Geolocator.requestPermission();
    }

    if (permiso == LocationPermission.deniedForever) {
      return PermisoGpsResultado.denegadoPermanentemente;
    }

    if (permiso == LocationPermission.denied) {
      return PermisoGpsResultado.denegado;
    }

    // LocationPermission.always || LocationPermission.whileInUse
    return PermisoGpsResultado.concedido;
  }

  @override
  Future<Ubicacion> obtenerPosicionActual({bool precisionAlta = true}) async {
    try {
      final posicion = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: precisionAlta
              ? LocationAccuracy.high    // F.1: creación de incidente
              : LocationAccuracy.medium, // F.3: marcador del denunciante en tracking
          timeLimit: Duration(seconds: precisionAlta ? 15 : 30),
        ),
      );
      return Ubicacion(latitud: posicion.latitude, longitud: posicion.longitude);
    } on LocationServiceDisabledException {
      throw const GeolocalizacionException(
        'El GPS está desactivado. Actívalo en los ajustes del dispositivo.',
      );
    } on PermissionDeniedException {
      throw const GeolocalizacionException(
        'No se concedió permiso de ubicación. '
        'Verifica los permisos de la app en ajustes.',
      );
    } catch (e) {
      throw GeolocalizacionException(
        'No se pudo obtener la ubicación: $e',
      );
    }
  }

  @override
  Stream<Ubicacion> streamPosicion({double distanciaFiltroMetros = 10.0}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanciaFiltroMetros.toInt(),
      ),
    ).map(
      (posicion) => Ubicacion(
        latitud: posicion.latitude,
        longitud: posicion.longitude,
      ),
    );
  }
}