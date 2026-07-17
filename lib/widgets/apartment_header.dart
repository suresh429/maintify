import 'package:flutter/material.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/role_theme.dart';

/// Reusable header card showing the apartment name, president name,
/// and the current user's role chip. Used at the top of every dashboard.
class ApartmentHeader extends StatelessWidget {
  final String apartmentName;
  final String presidentName;
  final UserRole role;

  const ApartmentHeader({
    super.key,
    required this.apartmentName,
    required this.presidentName,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final theme = RoleTheme.of(role);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = theme.effectivePrimary(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withOpacity(isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.apartment_outlined, color: accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  apartmentName,
                  style: AppTextStyles.subheading(color: cs.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.person_outline,
                        size: 12, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'President: $presidentName',
                        style: AppTextStyles.caption(color: cs.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _RoleChip(role: role, theme: theme),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final UserRole role;
  final RoleTheme theme;
  const _RoleChip({required this.role, required this.theme});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = theme.effectivePrimary(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withOpacity(isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        theme.label,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: accent,
        ),
      ),
    );
  }
}
