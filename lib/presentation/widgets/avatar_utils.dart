import 'package:flutter/material.dart';

class AvatarUtils {
  static const List<Color> _colors = [
    Color(0xFF3727AB),
    Color(0xFF5D4CD6),
    Color(0xFF00A8A8),
    Color(0xFFFF8A65),
    Color(0xFF4CAF50),
    Color(0xFFFFB300),
    Color(0xFF26C6DA),
    Color(0xFFEC407A),
  ];

  static Color colorFromName(String name) {
    if (name.trim().isEmpty) return _colors.first;
    final letter = name.trim().toUpperCase().codeUnitAt(0);
    return _colors[letter % _colors.length];
  }

  static String firstLetter(String name) {
    if (name.trim().isEmpty) return '?';
    return name.trim()[0].toUpperCase();
  }
}
