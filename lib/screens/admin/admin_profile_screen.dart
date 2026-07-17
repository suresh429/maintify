import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/apartment_provider.dart';
import '../../providers/theme_provider.dart';
import '../../core/utils/app_utils.dart';
import '../../widgets/change_password_sheet.dart';
import '../../widgets/logout_sheet.dart';
import '../shared/notifications_screen.dart';
import 'transfer_president_screen.dart';

class AdminProfileScreen extends StatelessWidget {
  const AdminProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    final aptProvider = context.watch<ApartmentProvider>();
    final apt = aptProvider.findById(user.apartmentId ?? '');
    final theme = RoleTheme.of(UserRole.admin);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // ── Gradient hero header ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 256,
            pinned: true,
            backgroundColor: theme.primary,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Profile',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: theme.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 48),
                      // Avatar
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.2),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.8), width: 2.5),
                        ),
                        child: Center(
                          child: Text(
                            user.avatarInitials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 32,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user.name,
                        style: AppTextStyles.heading3(color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      // President badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.5), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shield_outlined,
                                color: Colors.white, size: 13),
                            const SizedBox(width: 5),
                            Text(
                              'Apartment President',
                              style: AppTextStyles.caption(color: Colors.white)
                                  .copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info card
                  _SectionCard(
                    children: [
                      _InfoTile(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: user.email,
                        iconColor: theme.effectivePrimary(context),
                      ),
                      const _Divider(),
                      _InfoTile(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: user.phone.isNotEmpty
                            ? user.phone
                            : 'Not provided',
                        iconColor: theme.effectivePrimary(context),
                      ),
                      const _Divider(),
                      _InfoTile(
                        icon: Icons.apartment_outlined,
                        label: 'Apartment',
                        value: apt?.name ?? 'Unknown',
                        iconColor: theme.effectivePrimary(context),
                      ),
                      const _Divider(),
                      _InfoTile(
                        icon: Icons.tag_rounded,
                        label: 'Apartment Code',
                        value: apt?.code.isNotEmpty == true ? apt!.code : '—',
                        iconColor: theme.effectivePrimary(context),
                      ),
                      if (user.unit.isNotEmpty) ...[
                        const _Divider(),
                        _InfoTile(
                          icon: Icons.door_front_door_outlined,
                          label: 'Flat',
                          value: 'Flat ${user.unit}',
                          iconColor: theme.effectivePrimary(context),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 24),
                  Text('Settings',
                      style: AppTextStyles.heading3(
                          color: Theme.of(context).colorScheme.onSurface)),
                  const SizedBox(height: 12),

                  // Settings menu
                  _SectionCard(
                    children: [
                      _MenuTile(
                        icon: Icons.notifications_outlined,
                        label: 'Notifications',
                        iconColor: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF60A5FA)
                            : AppColors.blue,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const NotificationsScreen()),
                        ),
                      ),
                      const _Divider(),
                      _MenuTile(
                        icon: Icons.lock_outline_rounded,
                        label: 'Change Password',
                        iconColor: AppColors.purple,
                        onTap: () => showChangePasswordSheet(context),
                      ),
                      const _Divider(),
                      Consumer<ThemeProvider>(
                        builder: (context, tp, _) => _MenuTile(
                          icon: tp.isDarkMode
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                          label: 'Dark Mode',
                          iconColor: const Color(0xFF8B6CE8),
                          trailing: Switch.adaptive(
                            value: tp.isDarkMode,
                            onChanged: (_) => tp.toggle(),
                            activeColor: theme.primary,
                          ),
                          showChevron: false,
                          onTap: () => tp.toggle(),
                        ),
                      ),
                      const _Divider(),
                      _MenuTile(
                        icon: Icons.swap_horiz_rounded,
                        label: 'Transfer Presidency',
                        subtitle: 'Hand over to another resident',
                        iconColor: theme.effectivePrimary(context),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const TransferPresidentScreen()),
                        ),
                      ),
                      const _Divider(),
                      _MenuTile(
                        icon: Icons.privacy_tip_outlined,
                        label: 'Privacy Policy',
                        iconColor: theme.effectivePrimary(context),
                        onTap: () => AppUtils.launchPrivacyPolicy(context),
                      ),
                      const _Divider(),
                      _MenuTile(
                        icon: Icons.help_outline_rounded,
                        label: 'Help & Support',
                        iconColor: AppColors.pending,
                        onTap: () {},
                      ),
                      const _Divider(),
                      _MenuTile(
                        icon: Icons.info_outline_rounded,
                        label: 'About',
                        iconColor: AppColors.textSecondary,
                        onTap: () => _showAbout(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Logout
                  _SectionCard(
                    children: [
                      _MenuTile(
                        icon: Icons.logout_rounded,
                        label: 'Log Out',
                        iconColor: AppColors.overdue,
                        textColor: AppColors.overdue,
                        showChevron: false,
                        onTap: () async {
                          final confirm =
                              await showLogoutSheet(context, UserRole.admin);
                          if (confirm == true && context.mounted) {
                            context.read<AuthProvider>().logout();
                            Navigator.pushReplacementNamed(context, '/login');
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'About Maintify',
          style: TextStyle(
              fontFamily: 'Poppins', fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Maintify v2.1.0\nApartment Management Application\n\n© 2026 Maintify. All rights reserved.',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK',
                style: TextStyle(
                    fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Reusable section card ─────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Divider(
      height: 1,
      thickness: 1,
      color: cs.outline.withOpacity(0.5),
      indent: 16,
      endIndent: 16,
    );
  }
}

// ── Info tile ─────────────────────────────────────────────────────────────────

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTextStyles.caption(color: cs.onSurfaceVariant)),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: AppTextStyles.subheading(color: cs.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Menu tile ─────────────────────────────────────────────────────────────────

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color iconColor;
  final Color? textColor;
  final bool showChevron;
  final Widget? trailing;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.iconColor,
    this.textColor,
    this.showChevron = true,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: iconColor),
      ),
      title: Text(
        label,
        style: AppTextStyles.subheading(color: textColor ?? cs.onSurface)
            .copyWith(fontSize: 14),
      ),
      subtitle: subtitle != null
          ? Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(subtitle!,
                  style: AppTextStyles.caption(color: cs.onSurfaceVariant)),
            )
          : null,
      trailing: trailing ??
          (showChevron
              ? Icon(Icons.chevron_right_rounded,
                  color: cs.onSurfaceVariant, size: 20)
              : null),
    );
  }
}
