import 'package:flutter/material.dart';

class TipoIncidente {
  final String id;
  final String titulo;
  final String descripcion;
  final IconData icono;
  final Color color;

  TipoIncidente({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.icono,
    required this.color,
  });
}