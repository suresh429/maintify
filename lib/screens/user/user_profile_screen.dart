import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bill_provider.dart';
import '../../providers/apartment_provider.dart';
import 'complaints_screen.dart';
import 'i_paid_screen.dart';
import '../../widgets/change_password_sheet.dart';
import '../../widgets/logout_sheet.dart';
import '../shared/fcm_debug_screen.dart';

class UserProfileScreen extends StatelessWidget {
  const UserProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser!;
    final billProvider = context.watch<BillProvider>();
    final aptProvider = context.watch<ApartmentProvider>();
    final theme = RoleTheme.of(UserRole.user);

    final apt = aptProvider.findById(user.apartmentId ?? '');
    final allViews = billProvider.userBillViews(user.id);
    final paidCount = allViews.where((v) => v.payment.isPaid).length;
    final pendingCount = allViews.where((v) => !v.payment.isPaid).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Avatar hero card ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: theme.gradient,
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: theme.primary.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withOpacity(0.5), width: 2),
                  ),
                  child: Center(
                    child: Text(
                      user.avatarInitials,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 28,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(user.name,
                    style: AppTextStyles.heading2(color: Colors.white)),
                const SizedBox(height: 4),
                Text(user.email,
                    style: AppTextStyles.caption(
                        color: Colors.white.withOpacity(0.8))),
                const SizedBox(height: 18),
                // Stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ProfileStat(label: 'Unit', value: user.unit),
                    _VerticalDivider(),
                    _ProfileStat(
                        label: 'Paid', value: '$paidCount bills'),
                    _VerticalDivider(),
                    _ProfileStat(
                        label: 'Due', value: '$pendingCount bills'),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Apartment info card ───────────────────────────────────────────
          _SectionCard(
            title: 'Apartment',
            icon: Icons.apartment_outlined,
            iconColor: AppColors.blue,
            children: [
              _InfoRow(label: 'Name', value: apt?.name ?? '—'),
              _InfoRow(
                  label: 'Total Flats',
                  value: '${apt?.totalFlats ?? 0} flats'),
              _InfoRow(
                  label: 'President',
                  value: apt?.presidentName ?? 'Unassigned'),
            ],
          ),

          const SizedBox(height: 20),

          // ── Quick action ──────────────────────────────────────────────────
          _SectionLabel('Quick Action'),
          const SizedBox(height: 10),

          _ActionTile(
            icon: Icons.check_circle_outline_rounded,
            label: 'Report a Payment',
            subtitle:
                '$pendingCount pending bill${pendingCount != 1 ? 's' : ''} · notify admin',
            color: theme.primary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const IPaidScreen()),
            ),
          ),

          const SizedBox(height: 20),

          // ── Menu section ──────────────────────────────────────────────────
          _SectionLabel('More'),
          const SizedBox(height: 10),

          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                // Complaints
                _MenuTile(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Complaints',
                  subtitle: 'Raise or track issues',
                  iconColor: AppColors.blue,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ComplaintsScreen()),
                  ),
                ),
                const Divider(height: 1, indent: 56, color: Color(0xFFE0E0E0)),
                // Change Password
                _MenuTile(
                  icon: Icons.lock_reset_rounded,
                  label: 'Change Password',
                  subtitle: 'Update your login password',
                  iconColor: theme.primary,
                  onTap: () => showChangePasswordSheet(context),
                ),
                const Divider(height: 1, indent: 56,color: Color(0xFFE0E0E0),),
                // Role badge
                _MenuTile(
                  icon: Icons.verified_outlined,
                  label: 'Role',
                  subtitle: user.roleLabel,
                  iconColor: theme.primary,
                  trailing: null,
                  onTap: null,
                ),
                const Divider(height: 1, indent: 56,color: Color(0xFFE0E0E0),),
                // Phone
                _MenuTile(
                  icon: Icons.phone_outlined,
                  label: 'Mobile',
                  subtitle: user.phone.isNotEmpty ? user.phone : '—',
                  iconColor: AppColors.textSecondary,
                  onTap: null,
                ),
                const Divider(height: 1, indent: 56, color: Color(0xFFE0E0E0)),
                // FCM Debug
                _MenuTile(
                  icon: Icons.developer_mode_rounded,
                  label: 'FCM Debug',
                  subtitle: 'Push notification test & token',
                  iconColor: AppColors.blue,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FcmDebugScreen()),
                  ),
                ),
                const Divider(height: 1, indent: 56, color: Color(0xFFE0E0E0)),
                // Logout
                _MenuTile(
                  icon: Icons.logout_rounded,
                  label: 'Logout',
                  subtitle: 'Sign out of your account',
                  iconColor: AppColors.overdue,
                  labelColor: AppColors.overdue,
                  onTap: () async {
                    final confirm =
                        await showLogoutSheet(context, UserRole.user);
                    if (confirm == true && context.mounted) {
                      context.read<AuthProvider>().logout();
                      Navigator.pushReplacementNamed(context, '/login');
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _ProfileStat extends StatelessWidget {
  final String label;
  final String value;
  const _ProfileStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            color: Colors.white.withOpacity(0.75),
          ),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
        width: 1, height: 32, color: Colors.white.withOpacity(0.25));
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 1.0,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(title, style: AppTextStyles.subheading()),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.caption()),
          Text(
            value,
            style: AppTextStyles.bodySmall(color: AppColors.textPrimary)
                .copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
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
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTextStyles.subheading(
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: AppTextStyles.caption(
                          color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: AppColors.textSecondary, size: 15),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color iconColor;
  final Color? labelColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.iconColor,
    this.labelColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.bodyMedium(
                        color: labelColor ?? AppColors.textPrimary),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption(
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            trailing ??
                (onTap != null
                    ? const Icon(Icons.arrow_forward_ios_rounded,
                        color: AppColors.textSecondary, size: 14)
                    : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}
