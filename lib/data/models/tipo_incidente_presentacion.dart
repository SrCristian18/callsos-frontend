import 'package:flutter/material.dart';

import 'enums/tipo_incidente_enum.dart';

/// Datos de presentación (UI) para un [TipoIncidenteEnum].
///
/// F.0.2 — Separación de responsabilidades:
///
/// Antes, la clase `TipoIncidente` (en `data/models/tipo_incidente.dart`)
/// mezclaba el VALOR DE DOMINIO (lo que se envía al backend) con los datos
/// de PRESENTACIÓN (título, descripción, icono, color), y además usaba un
/// `id` de string arbitrario ("1".."6") sin relación con el dominio, y le
/// faltaba el tipo `ATENTADOS` (el backend define 7 tipos, el catálogo
/// anterior solo tenía 6).
///
/// Ahora:
/// - El VALOR DE DOMINIO es [TipoIncidenteEnum] (espejo exacto del backend).
/// - Los datos de PRESENTACIÓN son esta clase, [TipoIncidentePresentacion].
/// - La relación entre ambos es el mapa [catalogoTipos], indexado por
///   [TipoIncidenteEnum] (clave estable, no un id arbitrario).
///
/// El archivo `data/models/tipo_incidente.dart` (clase `TipoIncidente`
/// original) se mantiene por ahora SIN MODIFICAR para no romper las vistas
/// y viewmodels que aún lo usan (`ReporteViewModel`, `IncidenteViewModel`,
/// `IncidenteReportado`, `reporte_view.dart`, widgets de rol). Esas piezas
/// se migran a este nuevo modelo en F.1/F.2, cuando se reescriben por
/// completo según el roadmap acordado.
class TipoIncidentePresentacion {
  final String titulo;
  final String descripcion;
  final IconData icono;
  final Color color;

  const TipoIncidentePresentacion({
    required this.titulo,
    required this.descripcion,
    required this.icono,
    required this.color,
  });
}

/// Catálogo completo de presentación para los 7 tipos de incidente del
/// dominio (espejo de `com.callsos.backend.domain.enums.TipoIncidente`).
///
/// Los 6 primeros conservan título/descripción/icono/color del catálogo
/// anterior (`ReporteViewModel.incidentes`); se agrega `ATENTADOS`, que
/// faltaba.
const Map<TipoIncidenteEnum, TipoIncidentePresentacion> catalogoTipos = {
  TipoIncidenteEnum.RUIDO_EXCESIVO: TipoIncidentePresentacion(
    titulo: 'Ruido excesivo',
    descripcion: 'Problemas de contaminación sonora',
    icono: Icons.volume_up_rounded,
    color: Colors.pinkAccent,
  ),
  TipoIncidenteEnum.ABUSO_INFANTIL: TipoIncidentePresentacion(
    titulo: 'Abuso infantil',
    descripcion: 'Violencia o maltrato contra menores',
    icono: Icons.child_care,
    color: Colors.orange,
  ),
  TipoIncidenteEnum.INCIDENTE_DE_TRANSITO: TipoIncidentePresentacion(
    titulo: 'Incidente de tránsito',
    descripcion: 'Accidente o siniestro vial',
    icono: Icons.traffic,
    color: Colors.blue,
  ),
  TipoIncidenteEnum.RINAS_O_PELEAS: TipoIncidentePresentacion(
    titulo: 'Riñas o peleas',
    descripcion: 'Conflictos físicos entre personas',
    icono: Icons.groups,
    color: Colors.green,
  ),
  TipoIncidenteEnum.VIOLENCIA_DOMESTICA: TipoIncidentePresentacion(
    titulo: 'Violencia doméstica',
    descripcion: 'Agresión en el entorno familiar',
    icono: Icons.favorite,
    color: Colors.purple,
  ),
  TipoIncidenteEnum.ROBOS_O_ASALTOS: TipoIncidentePresentacion(
    titulo: 'Robos o asaltos',
    descripcion: 'Delito de hurto o atraco',
    icono: Icons.gpp_bad,
    color: Colors.red,
  ),
  TipoIncidenteEnum.ATENTADOS: TipoIncidentePresentacion(
    titulo: 'Atentados',
    descripcion: 'Actos violentos contra personas o bienes a gran escala',
    icono: Icons.warning_amber_rounded,
    color: Colors.deepOrange,
  ),
};