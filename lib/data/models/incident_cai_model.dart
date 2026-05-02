import 'package:flutter/material.dart';

enum EstadoIncidente { pendiente, completado }

class Incidente {
  final String id;
  final String titulo;
  final String descripcion;
  final IconData icono;
  final Color color;
  final String caiId; // A qué CAI le llegó este reporte
  final EstadoIncidente estado;

  Incidente({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.icono,
    required this.color,
    required this.caiId,
    this.estado = EstadoIncidente.pendiente,
  });
}