import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color blue = Color(0xFF1E3A8A);
  static const Color green = Color(0xFFC39A51);
  static const Color teal = Color(0xFF06B6D4);
  static const Color purple = Color(0xFF8B6CE8);

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

  // Role-based gradients — centerLeft (lighter) → centerRight (darker), same-family only
  static const List<Color> superAdminGradient = [
    Color(0xFF8B6CE8), // Violet 400 — lighter
    Color(0xFF6D28D9), // Violet 700 — darker
  ];

  static const List<Color> adminGradient = [
    Color(0xFF3B82F6), // Blue 500 — lighter
    Color(0xFF1E3A8A), // Blue 900 — darker
  ];

  static const List<Color> userGradient = [
    Color(0xFFC39A51), // Soft Gold — start
    Color(0xFF2A2D3E), // Dark Navy — end
  ];
}
