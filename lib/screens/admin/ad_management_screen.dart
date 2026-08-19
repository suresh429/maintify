import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/ads/ad_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../models/apartment_model.dart';
import '../../providers/ads_provider.dart';
import '../../providers/apartment_provider.dart';
import '../../providers/auth_provider.dart';

/// Super Admin — comprehensive ad management screen.
///
/// Controls:
///   • Global kill switch
///   • Banner (Phase 1)
///   • Interstitial + frequency/cooldown (Phase 2)
///   • Native toggle (Phase 3, disabled by default)
///   • Per-apartment ad control
class AdManagementScreen extends StatefulWidget {
  const AdManagementScreen({super.key});

  @override
  State<AdManagementScreen> createState() => _AdManagementScreenState();
}

class _AdManagementScreenState extends State<AdManagementScreen> {
  bool _isSaving = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Save helpers ─────────────────────────────────────────────────────────────

  Future<void> _save(AdConfig config) async {
    final auth = context.read<AuthProvider>();
    final uid = auth.currentUser?.id ?? '';
    debugPrint('[AdMgmt] _save() called — uid=$uid adsEnabled=${config.adsEnabled} '
        'banner=${config.bannerEnabled} interstitial=${config.interstitialEnabled}');
    setState(() => _isSaving = true);
    try {
      await context.read<AdsProvider>().updateAdConfig(config, uid);
      debugPrint('[AdMgmt] _save() SUCCESS');
      if (mounted) {
        AppUtils.showSnackBar(context, 'Settings saved',
            color: AppColors.paid);
      }
    } catch (e, st) {
      debugPrint('[AdMgmt] _save() FAILED: $e');
      debugPrint('[AdMgmt] StackTrace: $st');
      if (mounted) {
        AppUtils.showSnackBar(context, 'Failed to save. Please try again.',
            color: AppColors.overdue);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _setGlobal(bool value) async {
    final config = context.read<AdsProvider>().adConfig.copyWith(adsEnabled: value);
    await _save(config);
  }

  Future<void> _setBanner(bool value) async {
    final config = context.read<AdsProvider>().adConfig.copyWith(bannerEnabled: value);
    await _save(config);
  }

  Future<void> _setInterstitial(bool value) async {
    final config =
        context.read<AdsProvider>().adConfig.copyWith(interstitialEnabled: value);
    await _save(config);
  }

  Future<void> _setFrequency(int value) async {
    final config =
        context.read<AdsProvider>().adConfig.copyWith(interstitialFrequency: value);
    await _save(config);
  }

  Future<void> _setCooldown(int seconds) async {
    final config = context
        .read<AdsProvider>()
        .adConfig
        .copyWith(interstitialCooldownSeconds: seconds);
    await _save(config);
  }

  Future<void> _setNative(bool value) async {
    final config = context.read<AdsProvider>().adConfig.copyWith(nativeEnabled: value);
    await _save(config);
  }

  Future<void> _setApartmentAds(String aptId, bool value) async {
    final auth = context.read<AuthProvider>();
    final uid = auth.currentUser?.id ?? '';
    debugPrint('[AdMgmt] _setApartmentAds() aptId=$aptId value=$value uid=$uid');
    setState(() => _isSaving = true);
    try {
      await context.read<AdsProvider>().setApartmentAdsEnabled(aptId, value, uid);
      debugPrint('[AdMgmt] _setApartmentAds() SUCCESS');
      if (mounted) {
        AppUtils.showSnackBar(
          context,
          value ? 'Ads enabled for apartment' : 'Ads disabled for apartment',
          color: value ? AppColors.paid : AppColors.overdue,
        );
      }
    } catch (e, st) {
      debugPrint('[AdMgmt] _setApartmentAds() FAILED: $e');
      debugPrint('[AdMgmt] StackTrace: $st');
      if (mounted) {
        AppUtils.showSnackBar(context, 'Failed. Please try again.',
            color: AppColors.overdue);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Frequency/cooldown dialogs ────────────────────────────────────────────────

  Future<void> _showFrequencyDialog(int current) async {
    final controller =
        TextEditingController(text: current.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (_) => _NumberInputDialog(
        title: 'Interstitial Frequency',
        subtitle: 'Show an interstitial after every N eligible actions.',
        hint: 'Number of actions (e.g. 5)',
        controller: controller,
        min: 1,
        max: 50,
      ),
    );
    if (result != null) await _setFrequency(result);
  }

  Future<void> _showCooldownDialog(int currentSeconds) async {
    final controller =
        TextEditingController(text: (currentSeconds ~/ 60).toString());
    final result = await showDialog<int>(
      context: context,
      builder: (_) => _NumberInputDialog(
        title: 'Cooldown Period',
        subtitle: 'Minimum minutes between interstitial impressions.',
        hint: 'Minutes (e.g. 5)',
        controller: controller,
        min: 0,
        max: 120,
      ),
    );
    if (result != null) await _setCooldown(result * 60);
  }

  // ── Apartment ads toggle confirmation ─────────────────────────────────────────

  Future<void> _confirmApartmentToggle(
      ApartmentModel apt, bool currentValue) async {
    final newValue = !currentValue;
    final confirmed = await AppUtils.showConfirmDialog(
      context,
      title: newValue ? 'Enable Ads' : 'Disable Ads',
      message: newValue
          ? 'Enable advertisements for ${apt.name} residents?'
          : 'Disable advertisements for ${apt.name} residents?',
      confirmText: newValue ? 'Enable' : 'Disable',
      confirmColor: newValue ? AppColors.paid : AppColors.overdue,
    );
    if (confirmed == true) await _setApartmentAds(apt.id, newValue);
  }

  @override
  Widget build(BuildContext context) {
    final ads = context.watch<AdsProvider>();
    final apts = context.watch<ApartmentProvider>().apartments;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = RoleTheme.of(UserRole.admin).effectivePrimary(context);
    final config = ads.adConfig;

    final filteredApts = _searchQuery.isEmpty
        ? apts
        : apts
            .where((a) =>
                a.name.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark ? Colors.transparent : cs.surface,
        elevation: isDark ? 0 : 1,
        shadowColor: cs.shadow.withValues(alpha: 0.08),
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Ad Management',
          style: AppTextStyles.heading3(
              color: isDark ? Colors.white : cs.onSurface),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : cs.onSurface, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header banner ─────────────────────────────────────────
                _HeaderBanner(accent: accent),
                const SizedBox(height: 24),

                // ── Global Kill Switch ────────────────────────────────────
                _SectionLabel(label: 'GLOBAL ADVERTISING'),
                const SizedBox(height: 10),
                _ToggleCard(
                  icon: Icons.public_rounded,
                  iconColor: accent,
                  title: 'Advertisements',
                  subtitle:
                      'Master switch — when OFF, no ads appear anywhere.',
                  value: config.adsEnabled,
                  onChanged: _isSaving ? null : _setGlobal,
                ),
                const SizedBox(height: 8),
                if (!config.adsEnabled)
                  _WarningBanner(
                    message:
                        'All advertisements are currently disabled platform-wide.',
                  ),
                const SizedBox(height: 20),

                // ── Banner Ads (Phase 1) ──────────────────────────────────
                _SectionLabel(label: 'BANNER ADS — PHASE 1'),
                const SizedBox(height: 10),
                _ToggleCard(
                  icon: Icons.panorama_outlined,
                  iconColor: const Color(0xFF3B82F6),
                  title: 'Banner Ads',
                  subtitle:
                      'Standard banner shown at eligible screen locations.',
                  value: config.bannerEnabled,
                  onChanged:
                      (_isSaving || !config.adsEnabled) ? null : _setBanner,
                  disabled: !config.adsEnabled,
                ),
                const SizedBox(height: 20),

                // ── Interstitial Ads (Phase 2) ────────────────────────────
                _SectionLabel(label: 'INTERSTITIAL ADS — PHASE 2'),
                const SizedBox(height: 10),
                _ToggleCard(
                  icon: Icons.fullscreen_rounded,
                  iconColor: AppColors.purple,
                  title: 'Interstitial Ads',
                  subtitle:
                      'Full-screen ads shown at natural transition points.',
                  value: config.interstitialEnabled,
                  onChanged: (_isSaving || !config.adsEnabled)
                      ? null
                      : _setInterstitial,
                  disabled: !config.adsEnabled,
                ),
                const SizedBox(height: 12),
                // Frequency and cooldown — only relevant when interstitial is on
                _InterstitialSettings(
                  config: config,
                  isSaving: _isSaving,
                  onFrequencyTap: () =>
                      _showFrequencyDialog(config.interstitialFrequency),
                  onCooldownTap: () =>
                      _showCooldownDialog(config.interstitialCooldownSeconds),
                ),
                const SizedBox(height: 20),

                // ── Native Ads (Phase 3) ──────────────────────────────────
                _SectionLabel(label: 'NATIVE ADS — PHASE 3'),
                const SizedBox(height: 10),
                _ToggleCard(
                  icon: Icons.art_track_rounded,
                  iconColor: AppColors.pending,
                  title: 'Native Ads',
                  subtitle:
                      'Blended content-style ads. Enable only when placements are ready.',
                  value: config.nativeEnabled,
                  onChanged:
                      (_isSaving || !config.adsEnabled) ? null : _setNative,
                  disabled: !config.adsEnabled,
                ),
                const SizedBox(height: 8),
                _InfoBanner(
                  message:
                      'Native ads require custom layout templates. '
                      'Keep disabled until Phase 3 placements are implemented.',
                  color: AppColors.pending,
                ),
                const SizedBox(height: 24),

                // ── Apartment Controls ────────────────────────────────────
                _SectionLabel(label: 'APARTMENT AD CONTROLS'),
                const SizedBox(height: 10),

                // Search
                _SearchField(
                  controller: _searchController,
                  onChanged: (q) => setState(() => _searchQuery = q),
                ),
                const SizedBox(height: 12),

                if (filteredApts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text('No apartments found.',
                          style: AppTextStyles.bodyMedium(
                              color: cs.onSurfaceVariant)),
                    ),
                  )
                else
                  ...filteredApts.map((apt) => _ApartmentAdCard(
                        apt: apt,
                        isSaving: _isSaving,
                        globalEnabled: config.adsEnabled,
                        onToggle: () =>
                            _confirmApartmentToggle(apt, apt.adsEnabled),
                      )),
              ],
            ),
          ),

          // ── Saving overlay ────────────────────────────────────────────────
          if (_isSaving)
            const Positioned(
              top: 12,
              right: 20,
              child: _SavingIndicator(),
            ),
        ],
      ),
    );
  }
}

// ── Subwidgets ────────────────────────────────────────────────────────────────

class _HeaderBanner extends StatelessWidget {
  final Color accent;
  const _HeaderBanner({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: RoleTheme.of(UserRole.admin).gradient),
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
                Text('Ad Management',
                    style: AppTextStyles.subheading(color: Colors.white)),
                const SizedBox(height: 4),
                Text(
                  'Phase 1: Banner · Phase 2: Interstitial · Phase 3: Native',
                  style: AppTextStyles.caption(
                      color: Colors.white.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool disabled;

  const _ToggleCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = disabled ? cs.onSurfaceVariant : iconColor;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: effectiveColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: effectiveColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: disabled ? cs.onSurfaceVariant : cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: AppTextStyles.caption(
                          color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.paid,
            ),
          ],
        ),
      ),
    );
  }
}

class _InterstitialSettings extends StatelessWidget {
  final AdConfig config;
  final bool isSaving;
  final VoidCallback onFrequencyTap;
  final VoidCallback onCooldownTap;

  const _InterstitialSettings({
    required this.config,
    required this.isSaving,
    required this.onFrequencyTap,
    required this.onCooldownTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = config.adsEnabled && config.interstitialEnabled;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _SettingRow(
            icon: Icons.repeat_rounded,
            iconColor: enabled ? AppColors.purple : cs.onSurfaceVariant,
            label: 'Frequency',
            value: 'Every ${config.interstitialFrequency} actions',
            onTap: enabled && !isSaving ? onFrequencyTap : null,
          ),
          Divider(
              height: 1,
              color: cs.outlineVariant.withValues(alpha: 0.5),
              indent: 66),
          _SettingRow(
            icon: Icons.timer_outlined,
            iconColor: enabled ? AppColors.purple : cs.onSurfaceVariant,
            label: 'Cooldown',
            value: _formatCooldown(config.interstitialCooldownSeconds),
            onTap: enabled && !isSaving ? onCooldownTap : null,
          ),
        ],
      ),
    );
  }

  String _formatCooldown(int seconds) {
    if (seconds == 0) return 'No cooldown';
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    if (secs == 0) return '$mins ${mins == 1 ? "minute" : "minutes"}';
    return '${mins}m ${secs}s';
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _SettingRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: onTap != null
                          ? cs.onSurface
                          : cs.onSurfaceVariant,
                    )),
              ),
              Text(value,
                  style: AppTextStyles.caption(
                      color: onTap != null
                          ? cs.onSurface
                          : cs.onSurfaceVariant)),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded,
                  size: 18,
                  color: onTap != null
                      ? cs.onSurfaceVariant
                      : cs.onSurfaceVariant.withValues(alpha: 0.4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  final String message;
  const _WarningBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.overdue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.overdue.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 16, color: AppColors.overdue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: AppTextStyles.caption(color: cs.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String message;
  final Color color;
  const _InfoBanner({required this.message, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: AppTextStyles.caption(color: cs.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchField(
      {required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(
          fontFamily: 'Poppins', fontSize: 14, color: cs.onSurface),
      decoration: InputDecoration(
        hintText: 'Search apartment…',
        hintStyle: AppTextStyles.caption(color: cs.onSurfaceVariant),
        prefixIcon:
            Icon(Icons.search_rounded, color: cs.onSurfaceVariant, size: 20),
        filled: true,
        fillColor: isDark
            ? const Color(0xFF1E293B)
            : cs.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: RoleTheme.of(UserRole.admin)
                  .effectivePrimary(context)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

class _ApartmentAdCard extends StatelessWidget {
  final ApartmentModel apt;
  final bool isSaving;
  final bool globalEnabled;
  final VoidCallback onToggle;

  const _ApartmentAdCard({
    required this.apt,
    required this.isSaving,
    required this.globalEnabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final adsOn = apt.adsEnabled;
    final statusColor = adsOn ? AppColors.paid : AppColors.overdue;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.apartment_outlined,
                size: 18, color: Color(0xFF3B82F6)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  apt.name,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      adsOn ? 'Ads Enabled' : 'Ads Disabled',
                      style: AppTextStyles.caption(color: statusColor),
                    ),
                    if (!globalEnabled) ...[
                      const SizedBox(width: 8),
                      Text('(global OFF)',
                          style: AppTextStyles.caption(
                              color: cs.onSurfaceVariant)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: adsOn,
            onChanged: isSaving ? null : (_) => onToggle(),
            activeThumbColor: AppColors.paid,
          ),
        ],
      ),
    );
  }
}

class _SavingIndicator extends StatelessWidget {
  const _SavingIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text('Saving…',
              style: AppTextStyles.caption(
                  color: Theme.of(context).colorScheme.onSurface)),
        ],
      ),
    );
  }
}

// ── Number input dialog ───────────────────────────────────────────────────────

class _NumberInputDialog extends StatelessWidget {
  final String title;
  final String subtitle;
  final String hint;
  final TextEditingController controller;
  final int min;
  final int max;

  const _NumberInputDialog({
    required this.title,
    required this.subtitle,
    required this.hint,
    required this.controller,
    required this.min,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title,
          style: const TextStyle(
              fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle,
              style: AppTextStyles.bodySmall(
                  color: cs.onSurfaceVariant)),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofocus: true,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppTextStyles.caption(
                  color: cs.onSurfaceVariant),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(fontFamily: 'Poppins')),
        ),
        TextButton(
          onPressed: () {
            final val = int.tryParse(controller.text) ?? 0;
            if (val < min || val > max) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Enter a value between $min and $max.'),
              ));
              return;
            }
            Navigator.pop(context, val);
          },
          child: Text('Save',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
                color: RoleTheme.of(UserRole.admin)
                    .effectivePrimary(context),
              )),
        ),
      ],
    );
  }
}
