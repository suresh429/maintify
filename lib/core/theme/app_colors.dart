import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color blue = Color(0xFF1E3A8A);
  static const Color green = Color(0xFF22C55E);
  static const Color teal = Color(0xFF06B6D4);
  static const Color purple = Color(0xFF8B5CF6);

  // Background
  static const Color lightGray = Color(0xFFF1F5F9);
  static const Color white = Color(0xFFFFFFFF);

  // Text
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);

  // Status
  static const Color paid = Color(0xFF22C55E);
  static const Color pending = Color(0xFFF59E0B);
  static const Color overdue = Color(0xFFEF4444);

  // Card shadow
  static const Color shadow = Color(0x1A000000);

  // Role-based gradients
  static const List<Color> superAdminGradient = [
    Color(0xFF8B5CF6),
    Color(0xFF1E3A8A),
  ];

  static const List<Color> adminGradient = [
    Color(0xFF1E3A8A),
    Color(0xFF06B6D4),
  ];

  static const List<Color> userGradient = [
    Color(0xFF22C55E),
    Color(0xFF06B6D4),
  ];
}