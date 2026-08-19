import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../providers/ads_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/apartment_provider.dart';

/// President — controls advertising for their own apartment only.
class PresidentAdvertisingScreen extends StatefulWidget {
  const PresidentAdvertisingScreen({super.key});

  @override
  State<PresidentAdvertisingScreen> createState() =>
      _PresidentAdvertisingScreenState();
}

class _PresidentAdvertisingScreenState
    extends State<PresidentAdvertisingScreen> {
  bool _isSaving = false;

  Future<void> _setApartmentAds(bool value) async {
    final auth = context.read<AuthProvider>();
    final ads = context.read<AdsProvider>();
    final aptId = auth.currentUser?.apartmentId ?? '';
    final uid = auth.currentUser?.id ?? '';
    if (aptId.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await ads.setApartmentAdsEnabled(aptId, value, uid);
      if (mounted) {
        AppUtils.showSnackBar(
          context,
          value
              ? 'Advertising enabled for your apartment'
              : 'Advertising disabled for your apartment',
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
    final auth = context.read<AuthProvider>();
    final aptId = auth.currentUser?.apartmentId ?? '';
    final apt = context.watch<ApartmentProvider>().findById(aptId);

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = RoleTheme.of(UserRole.president).effectivePrimary(context);

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
            // ── Apartment header banner ───────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: RoleTheme.of(UserRole.president).gradient),
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
                          'Apartment Advertising',
                          style:
                              AppTextStyles.subheading(color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          apt?.name ?? 'Your Apartment',
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

            // ── Global status note ────────────────────────────────────────
            if (!ads.adConfig.adsEnabled) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.overdue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.overdue.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 18, color: AppColors.overdue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Platform-wide advertising is currently disabled by the super admin. '
                        'Ads will not be shown even if enabled here.',
                        style: AppTextStyles.bodySmall(
                            color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Section label ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                'APARTMENT ADVERTISING',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                  letterSpacing: 1.1,
                ),
              ),
            ),

            // ── Toggle card ───────────────────────────────────────────────
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
                              child: Icon(Icons.apartment_outlined,
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
                                    'Control ads for residents of this apartment.',
                                    style: AppTextStyles.caption(
                                        color: cs.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: ads.apartmentAdsEnabled,
                              onChanged:
                                  _isSaving ? null : _setApartmentAds,
                              activeThumbColor: AppColors.paid,
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Info ──────────────────────────────────────────────────────
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
                      'When disabled, no advertisements will be shown to '
                      'residents of this apartment. Changes take effect immediately '
                      'without an app update.',
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
