import 'package:flutter/material.dart';

class IncidentType {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  IncidentType({
    required this.title, 
    required this.subtitle, 
    required this.icon, 
    required this.color
  });
}