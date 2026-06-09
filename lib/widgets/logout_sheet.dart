import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/role_theme.dart';

/// Shows a premium role-themed logout confirmation bottom sheet.
/// Returns `true` if the user confirmed logout, `false` / `null` if dismissed.
Future<bool?> showLogoutSheet(BuildContext context, UserRole role) {
  HapticFeedback.mediumImpact();
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    useRootNavigator: true,
    builder: (_) => _LogoutSheet(role: role),
  );
}

class _LogoutSheet extends StatelessWidget {
  final UserRole role;
  const _LogoutSheet({required this.role});

  @override
  Widget build(BuildContext context) {
    final theme = RoleTheme.of(role);
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 14, 24, 24 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ───────────────────────────────────────────────
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 30),

          // ── Role-coloured icon ring ────────────────────────────────────
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  theme.primary.withOpacity(0.14),
                  theme.primary.withOpacity(0.07),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: theme.primary.withOpacity(0.22),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.power_settings_new_rounded,
                color: theme.primary,
                size: 34,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Title ─────────────────────────────────────────────────────
          Text('Logout?', style: AppTextStyles.heading2()),
          const SizedBox(height: 8),

          // ── Subtitle ──────────────────────────────────────────────────
          Text(
            "You'll be signed out of your account.\nYou can log back in anytime.",
            style:
                AppTextStyles.bodySmall(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // ── Logout button (role gradient) ─────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: theme.gradient,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: theme.primary.withOpacity(0.32),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context, true);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.logout_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text('Logout',
                          style:
                              AppTextStyles.buttonText(color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Cancel button ─────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(
                    color: Color(0xFFE2E8F0), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                backgroundColor: const Color(0xFFF8FAFC),
                foregroundColor: AppColors.textPrimary,
                padding: EdgeInsets.zero,
              ),
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style:
                    AppTextStyles.buttonText(color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
