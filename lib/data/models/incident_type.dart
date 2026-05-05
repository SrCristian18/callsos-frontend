import 'package:flutter/material.dart';

class IncidentType {
  final String id;
  final String title;
  final IconData icon;
  final Color color;

  IncidentType({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
  });
}