import 'package:flutter/material.dart';
import 'app_colors.dart';

enum UserRole { superAdmin, admin, user }

class RoleTheme {
  final Color primary;
  final Color darkPrimary; // lighter variant for dark mode surfaces
  final Color secondary;
  final List<Color> gradient;
  final Color lightBackground;
  final String label;
  final IconData icon;

  const RoleTheme({
    required this.primary,
    required this.darkPrimary,
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
          primary: Color(0xFF6D28D9),     // Violet 700 — for light mode
          darkPrimary: Color(0xFFA78BFA), // Violet 400 — light purple for dark mode
          secondary: Color(0xFFA78BFA),
          gradient: AppColors.superAdminGradient,
          lightBackground: Color(0xFFF5F3FF),
          label: 'Super Admin',
          icon: Icons.shield_outlined,
        );
      case UserRole.admin:
        return const RoleTheme(
          primary: Color(0xFF1E3A8A),     // Blue 900 — for light mode
          darkPrimary: Color(0xFF60A5FA), // Blue 400 — light blue for dark mode
          secondary: Color(0xFF3B82F6),
          gradient: AppColors.adminGradient,
          lightBackground: Color(0xFFEFF6FF),
          label: 'Admin',
          icon: Icons.manage_accounts_outlined,
        );
      case UserRole.user:
        return const RoleTheme(
          primary: Color(0xFF2A2D3E),     // Dark navy — for light mode
          darkPrimary: Color(0xFFFECB6E), // Gold/amber — light gold for dark mode
          secondary: Color(0xFFFECB6E),
          gradient: AppColors.userGradient,
          lightBackground: Color(0xFFF0FDF4),
          label: 'Resident',
          icon: Icons.person_outline,
        );
    }
  }

  /// Returns the appropriate accent color based on current brightness.
  Color effectivePrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? darkPrimary : primary;
  }

  Color get chipColor => primary.withOpacity(0.12);
  Color get chipTextColor => primary;
}
