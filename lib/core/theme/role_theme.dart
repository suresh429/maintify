import 'package:flutter/material.dart';
import 'app_colors.dart';

enum UserRole { superAdmin, admin, user }

class RoleTheme {
  final Color primary;
  final Color secondary;
  final List<Color> gradient;
  final Color lightBackground;
  final String label;
  final IconData icon;

  const RoleTheme({
    required this.primary,
    required this.secondary,
    required this.gradient,
    required this.lightBackground,
    required this.label,
    required this.icon,
  });

  static RoleTheme of(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return const RoleTheme(
          primary: AppColors.purple,
          secondary: AppColors.blue,
          gradient: AppColors.superAdminGradient,
          lightBackground: Color(0xFFF5F3FF),
          label: 'Super Admin',
          icon: Icons.shield_outlined,
        );
      case UserRole.admin:
        return const RoleTheme(
          primary: AppColors.blue,
          secondary: AppColors.teal,
          gradient: AppColors.adminGradient,
          lightBackground: Color(0xFFEFF6FF),
          label: 'Admin',
          icon: Icons.manage_accounts_outlined,
        );
      case UserRole.user:
        return const RoleTheme(
          primary: AppColors.green,
          secondary: AppColors.teal,
          gradient: AppColors.userGradient,
          lightBackground: Color(0xFFF0FDF4),
          label: 'Resident',
          icon: Icons.person_outline,
        );
    }
  }

  Color get chipColor => primary.withOpacity(0.12);
  Color get chipTextColor => primary;
}
