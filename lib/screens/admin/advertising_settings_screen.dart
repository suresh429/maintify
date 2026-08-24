import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../providers/ads_provider.dart';
import '../../providers/auth_provider.dart';

/// Super Admin — controls the global advertising toggle.
/// Reads/writes Firestore via [AdsProvider].
class AdvertisingSettingsScreen extends StatefulWidget {
  const AdvertisingSettingsScreen({super.key});

  @override
  State<AdvertisingSettingsScreen> createState() =>
      _AdvertisingSettingsScreenState();
}

class _AdvertisingSettingsScreenState
    extends State<AdvertisingSettingsScreen> {
  bool _isSaving = false;

  Future<void> _setGlobal(bool value) async {
    final ads = context.read<AdsProvider>();
    final auth = context.read<AuthProvider>();
    final uid = auth.currentUser?.id ?? '';
    setState(() => _isSaving = true);
    try {
      await ads.setGlobalAdsEnabled(value, uid);
      if (mounted) {
        AppUtils.showSnackBar(
          context,
          value
              ? 'Advertising enabled globally'
              : 'Advertising disabled globally',
          color: value ? AppColors.paid : AppColors.overdue,
        );
      }
    } catch (_) {
      if (mounted) {
        AppUtils.showSnackBar(
          context,
          'Failed to update. Please try again.',
          color: AppColors.overdue,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ads = context.watch<AdsProvider>();
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = RoleTheme.of(UserRole.admin).effectivePrimary(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark ? Colors.transparent : cs.surface,
        elevation: isDark ? 0 : 1,
        shadowColor: cs.shadow.withValues(alpha: 0.08),
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Advertising',
          style: AppTextStyles.heading3(
              color: isDark ? Colors.white : cs.onSurface),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : cs.onSurface, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: RoleTheme.of(UserRole.admin).gradient),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.ads_click_rounded,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Advertising Control',
                          style:
                              AppTextStyles.subheading(color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage platform-wide ad settings.',
                          style: AppTextStyles.bodySmall(
                              color: Colors.white.withValues(alpha: 0.85)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Section label ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                'GLOBAL ADVERTISING',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                  letterSpacing: 1.1,
                ),
              ),
            ),

            // ── Global toggle card ────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _isSaving
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.public_rounded,
                                  size: 18, color: accent),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Show advertisements',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                  Text(
                                    'Enable or disable ads across the platform.',
                                    style: AppTextStyles.caption(
                                        color: cs.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: ads.globalAdsEnabled,
                              onChanged: _isSaving ? null : _setGlobal,
                              activeThumbColor: AppColors.paid,
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Explanation ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accent.withValues(alpha: 0.15)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'When global advertising is disabled, no advertisements '
                      'are shown in any apartment regardless of their individual '
                      'settings. Each apartment president can additionally control '
                      'ads for their own residents.',
                      style: AppTextStyles.bodySmall(
                          color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
