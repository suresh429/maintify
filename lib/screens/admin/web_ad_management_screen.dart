import 'package:flutter/material.dart';
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
import '../../widgets/web/web_page_container.dart';

/// Web-first Ad Management screen for the super admin.
///
/// Rendered inside [WebAppShell]'s content area (no Scaffold/AppBar needed).
/// Controls global ad config (banner, interstitial, native) and per-apartment
/// ad toggles — all backed by live Firestore streams via [AdsProvider].
class WebAdManagementScreen extends StatefulWidget {
  const WebAdManagementScreen({super.key});

  @override
  State<WebAdManagementScreen> createState() => _WebAdManagementScreenState();
}

class _WebAdManagementScreenState extends State<WebAdManagementScreen> {
  bool _isSaving = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Save helpers ─────────────────────────────────────────────────────────────

  Future<void> _save(AdConfig config) async {
    final auth = context.read<AuthProvider>();
    final uid = auth.currentUser?.id ?? '';
    setState(() => _isSaving = true);
    try {
      await context.read<AdsProvider>().updateAdConfig(config, uid);
      if (mounted) {
        AppUtils.showSnackBar(context, 'Settings saved', color: AppColors.paid);
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showSnackBar(
          context,
          'Failed to save. Please try again.',
          color: AppColors.overdue,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _setGlobal(bool value) async {
    final config =
        context.read<AdsProvider>().adConfig.copyWith(adsEnabled: value);
    await _save(config);
  }

  Future<void> _setBanner(bool value) async {
    final config =
        context.read<AdsProvider>().adConfig.copyWith(bannerEnabled: value);
    await _save(config);
  }

  Future<void> _setInterstitial(bool value) async {
    final config = context
        .read<AdsProvider>()
        .adConfig
        .copyWith(interstitialEnabled: value);
    await _save(config);
  }

  Future<void> _setFrequency(int value) async {
    final config = context
        .read<AdsProvider>()
        .adConfig
        .copyWith(interstitialFrequency: value);
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
    final config =
        context.read<AdsProvider>().adConfig.copyWith(nativeEnabled: value);
    await _save(config);
  }

  Future<void> _setApartmentAds(String aptId, bool value) async {
    final auth = context.read<AuthProvider>();
    final uid = auth.currentUser?.id ?? '';
    setState(() => _isSaving = true);
    try {
      await context
          .read<AdsProvider>()
          .setApartmentAdsEnabled(aptId, value, uid);
      if (mounted) {
        AppUtils.showSnackBar(
          context,
          value ? 'Ads enabled for apartment' : 'Ads disabled for apartment',
          color: value ? AppColors.paid : AppColors.overdue,
        );
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showSnackBar(
          context,
          'Failed. Please try again.',
          color: AppColors.overdue,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

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

  // ── Preset dialogs ────────────────────────────────────────────────────────────

  Future<void> _showFrequencyDialog(int current) async {
    final result = await showDialog<int>(
      context: context,
      builder: (_) => _PresetDialog(
        title: 'Interstitial Frequency',
        subtitle: 'Show an interstitial after every N eligible actions.',
        options: const [
          _PresetOption(label: 'Every 3 actions', value: 3),
          _PresetOption(label: 'Every 5 actions', value: 5),
          _PresetOption(label: 'Every 10 actions', value: 10),
          _PresetOption(label: 'Every 15 actions', value: 15),
        ],
        currentValue: current,
      ),
    );
    if (result != null) await _setFrequency(result);
  }

  Future<void> _showCooldownDialog(int currentSeconds) async {
    final result = await showDialog<int>(
      context: context,
      builder: (_) => _PresetDialog(
        title: 'Cooldown Period',
        subtitle: 'Minimum time between interstitial impressions.',
        options: const [
          _PresetOption(label: '1 minute', value: 60),
          _PresetOption(label: '5 minutes', value: 300),
          _PresetOption(label: '10 minutes', value: 600),
          _PresetOption(label: '15 minutes', value: 900),
          _PresetOption(label: '30 minutes', value: 1800),
        ],
        currentValue: currentSeconds,
      ),
    );
    if (result != null) await _setCooldown(result);
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final adsProvider = context.watch<AdsProvider>();
    final apts = context.watch<ApartmentProvider>().apartments;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = RoleTheme.of(UserRole.admin).effectivePrimary(context);

    if (!adsProvider.isLoaded) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: accent),
            const SizedBox(height: 16),
            Text(
              'Loading ad configuration…',
              style: AppTextStyles.bodyMedium(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    final config = adsProvider.adConfig;

    final filteredApts = _searchQuery.isEmpty
        ? apts
        : apts
            .where((a) =>
                a.name.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return Stack(
      children: [
        SingleChildScrollView(
          child: WebPageContainer(
            maxWidth: 960,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────────────
                _WebHeader(accent: accent, isDark: isDark),
                const SizedBox(height: 24),

                // ── Global Kill Switch ───────────────────────────────────────
                _SectionLabel(label: 'GLOBAL ADVERTISING'),
                const SizedBox(height: 10),
                _AdToggleCard(
                  icon: Icons.public_rounded,
                  iconColor: accent,
                  title: 'Advertisements',
                  subtitle:
                      'Master switch — when OFF, no ads appear anywhere.',
                  value: config.adsEnabled,
                  disabled: false,
                  onChanged: _isSaving ? null : _setGlobal,
                ),
                const SizedBox(height: 8),
                if (!config.adsEnabled)
                  _WarningBanner(
                    message:
                        'All advertisements are currently disabled platform-wide.',
                  ),
                const SizedBox(height: 20),

                // ── Banner Ads (Phase 1) ─────────────────────────────────────
                _SectionLabel(label: 'BANNER ADS — PHASE 1'),
                const SizedBox(height: 10),
                _AdToggleCard(
                  icon: Icons.panorama_outlined,
                  iconColor: const Color(0xFF3B82F6),
                  title: 'Banner Ads',
                  subtitle:
                      'Standard banner shown at eligible screen locations.',
                  value: config.bannerEnabled,
                  disabled: !config.adsEnabled,
                  onChanged:
                      (_isSaving || !config.adsEnabled) ? null : _setBanner,
                ),
                const SizedBox(height: 20),

                // ── Interstitial Ads (Phase 2) ───────────────────────────────
                _SectionLabel(label: 'INTERSTITIAL ADS — PHASE 2'),
                const SizedBox(height: 10),
                _AdToggleCard(
                  icon: Icons.fullscreen_rounded,
                  iconColor: AppColors.purple,
                  title: 'Interstitial Ads',
                  subtitle:
                      'Full-screen ads shown at natural transition points.',
                  value: config.interstitialEnabled,
                  disabled: !config.adsEnabled,
                  onChanged: (_isSaving || !config.adsEnabled)
                      ? null
                      : _setInterstitial,
                ),
                const SizedBox(height: 12),
                _InterstitialSettingsCard(
                  config: config,
                  isSaving: _isSaving,
                  onFrequencyTap: () =>
                      _showFrequencyDialog(config.interstitialFrequency),
                  onCooldownTap: () =>
                      _showCooldownDialog(config.interstitialCooldownSeconds),
                ),
                const SizedBox(height: 20),

                // ── Native Ads (Phase 3) ─────────────────────────────────────
                _SectionLabel(label: 'NATIVE ADS — PHASE 3'),
                const SizedBox(height: 10),
                _AdToggleCard(
                  icon: Icons.art_track_rounded,
                  iconColor: AppColors.pending,
                  title: 'Native Ads',
                  subtitle:
                      'Blended content-style ads. Enable only when placements are ready.',
                  value: config.nativeEnabled,
                  disabled: !config.adsEnabled,
                  onChanged:
                      (_isSaving || !config.adsEnabled) ? null : _setNative,
                ),
                const SizedBox(height: 8),
                _InfoBanner(
                  message:
                      'Native ads require custom layout templates. '
                      'Keep disabled until Phase 3 placements are implemented.',
                  color: AppColors.pending,
                ),
                const SizedBox(height: 24),

                // ── Apartment Ad Controls ────────────────────────────────────
                _SectionLabel(label: 'APARTMENT ADVERTISING'),
                const SizedBox(height: 10),
                _SearchField(
                  controller: _searchController,
                  onChanged: (q) => setState(() => _searchQuery = q),
                ),
                const SizedBox(height: 12),

                if (filteredApts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'No apartments found.',
                        style: AppTextStyles.bodyMedium(
                            color: cs.onSurfaceVariant),
                      ),
                    ),
                  )
                else
                  ...filteredApts.map((apt) => _ApartmentAdRow(
                        apt: apt,
                        isSaving: _isSaving,
                        globalEnabled: config.adsEnabled,
                        onToggle: () =>
                            _confirmApartmentToggle(apt, apt.adsEnabled),
                      )),

                const SizedBox(height: 32),

                // ── Last updated ─────────────────────────────────────────────
                if (config.updatedAt != null)
                  _LastUpdatedRow(config: config),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),

        // ── Saving overlay ───────────────────────────────────────────────────
        if (_isSaving)
          const Positioned(
            top: 12,
            right: 20,
            child: _SavingOverlay(),
          ),
      ],
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _WebHeader extends StatelessWidget {
  final Color accent;
  final bool isDark;

  const _WebHeader({required this.accent, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient:
                LinearGradient(colors: RoleTheme.of(UserRole.admin).gradient),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.ads_click_rounded,
              color: Colors.white, size: 24),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ad Management',
              style: AppTextStyles.heading3(color: cs.onSurface),
            ),
            const SizedBox(height: 2),
            Text(
              'Control how advertisements appear across Maintify',
              style: AppTextStyles.caption(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

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

// ── Ad toggle card ────────────────────────────────────────────────────────────

class _AdToggleCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final bool disabled;
  final ValueChanged<bool>? onChanged;

  const _AdToggleCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.disabled,
    required this.onChanged,
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
            color:
                Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: effectiveColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: effectiveColor),
            ),
            const SizedBox(width: 16),
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
                  Text(
                    subtitle,
                    style: AppTextStyles.caption(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
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

// ── Interstitial settings card ────────────────────────────────────────────────

class _InterstitialSettingsCard extends StatelessWidget {
  final AdConfig config;
  final bool isSaving;
  final VoidCallback onFrequencyTap;
  final VoidCallback onCooldownTap;

  const _InterstitialSettingsCard({
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
            color:
                Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
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
            indent: 70,
          ),
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color:
                        onTap != null ? cs.onSurface : cs.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                value,
                style: AppTextStyles.caption(
                  color: onTap != null ? cs.onSurface : cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: onTap != null
                    ? cs.onSurfaceVariant
                    : cs.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Warning / Info banners ────────────────────────────────────────────────────

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

// ── Search field ──────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style:
          TextStyle(fontFamily: 'Poppins', fontSize: 14, color: cs.onSurface),
      decoration: InputDecoration(
        hintText: 'Search apartment…',
        hintStyle: AppTextStyles.caption(color: cs.onSurfaceVariant),
        prefixIcon: Icon(Icons.search_rounded,
            color: cs.onSurfaceVariant, size: 20),
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : cs.surface,
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
              color: RoleTheme.of(UserRole.admin).effectivePrimary(context)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

// ── Apartment ad row ──────────────────────────────────────────────────────────

class _ApartmentAdRow extends StatelessWidget {
  final ApartmentModel apt;
  final bool isSaving;
  final bool globalEnabled;
  final VoidCallback onToggle;

  const _ApartmentAdRow({
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
            color:
                Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
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
                size: 20, color: Color(0xFF3B82F6)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  apt.name,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
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
                    const SizedBox(width: 6),
                    Text(
                      adsOn ? 'Ads Enabled' : 'Ads Disabled',
                      style: AppTextStyles.caption(color: statusColor),
                    ),
                    if (!globalEnabled) ...[
                      const SizedBox(width: 8),
                      Text(
                        '(global OFF)',
                        style: AppTextStyles.caption(
                            color: cs.onSurfaceVariant),
                      ),
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

// ── Last updated row ──────────────────────────────────────────────────────────

class _LastUpdatedRow extends StatelessWidget {
  final AdConfig config;
  const _LastUpdatedRow({required this.config});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateStr = AppUtils.formatDateTime(config.updatedAt!);
    final by = config.updatedBy;
    return Row(
      children: [
        Icon(Icons.update_rounded, size: 14, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          by != null && by.isNotEmpty
              ? 'Last updated: $dateStr by $by'
              : 'Last updated: $dateStr',
          style: AppTextStyles.caption(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

// ── Saving overlay ────────────────────────────────────────────────────────────

class _SavingOverlay extends StatelessWidget {
  const _SavingOverlay();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface,
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
              style: AppTextStyles.caption(color: cs.onSurface)),
        ],
      ),
    );
  }
}

// ── Preset dialog ─────────────────────────────────────────────────────────────

class _PresetOption {
  final String label;
  final int value;
  const _PresetOption({required this.label, required this.value});
}

class _PresetDialog extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<_PresetOption> options;
  final int currentValue;

  const _PresetDialog({
    required this.title,
    required this.subtitle,
    required this.options,
    required this.currentValue,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = RoleTheme.of(UserRole.admin).effectivePrimary(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitle,
            style: AppTextStyles.bodySmall(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          ...options.map((opt) {
            final isSelected = opt.value == currentValue;
            return InkWell(
              onTap: () => Navigator.pop(context, opt.value),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? accent.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? accent.withValues(alpha: 0.4)
                        : cs.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        opt.label,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color:
                              isSelected ? accent : cs.onSurface,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle_rounded,
                          size: 18, color: accent),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(fontFamily: 'Poppins'),
          ),
        ),
      ],
    );
  }
}
