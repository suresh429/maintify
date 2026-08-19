import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bill_provider.dart';
import '../../providers/apartment_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/notification_provider.dart';
import '../../models/user_model.dart';
import '../../models/apartment_model.dart';
import '../../core/utils/app_utils.dart';
import '../../core/utils/web_navigator.dart'
    if (dart.library.html) '../../core/utils/web_navigator_web.dart';
import '../../widgets/change_password_sheet.dart';
import '../../widgets/logout_sheet.dart';
import '../shared/notifications_screen.dart';

class ResidentProfileScreen extends StatefulWidget {
  const ResidentProfileScreen({super.key});

  @override
  State<ResidentProfileScreen> createState() => _ResidentProfileScreenState();
}

class _ResidentProfileScreenState extends State<ResidentProfileScreen> {
  final _scrollController = ScrollController();
  bool _isCollapsed = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final collapsed =
          _scrollController.hasClients && _scrollController.offset > 130;
      if (collapsed != _isCollapsed) {
        setState(() => _isCollapsed = collapsed);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    final apt =
        context.watch<ApartmentProvider>().findById(user.apartmentId ?? '');
    final billProvider = context.watch<BillProvider>();
    final allViews = billProvider.userBillViews(user.id);
    final paidCount = allViews.where((v) => v.payment.isPaid).length;
    final pendingCount = allViews.where((v) => !v.payment.isPaid).length;
    final isWeb = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          _ProfileSliverAppBar(
            user: user,
            apt: apt,
            isCollapsed: _isCollapsed,
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isWeb ? 720 : double.infinity),
                child: Padding(
              padding: EdgeInsets.fromLTRB(isWeb ? 24 : 8, 20, isWeb ? 24 : 8, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Apartment code spotlight
                  if (apt != null && apt.code.isNotEmpty) ...[
                    _ApartmentCodeCard(apt: apt, outerContext: context),
                    const SizedBox(height: 20),
                  ],

                  // Info section
                  _SectionLabel(label: 'Information'),
                  const SizedBox(height: 10),
                  _InfoCard(user: user, apt: apt),
                  const SizedBox(height: 20),

                  // Quick stats
                  _SectionLabel(label: 'My Bills'),
                  const SizedBox(height: 10),
                  _StatsRow(paidCount: paidCount, pendingCount: pendingCount),
                  const SizedBox(height: 24),

                  // Settings — Account
                  _SectionLabel(label: 'Account'),
                  const SizedBox(height: 10),
                  _SettingCard(
                    tiles: [
                      _SettingTile(
                        icon: Icons.lock_outline_rounded,
                        label: 'Change Password',
                        iconColor: AppColors.purple,
                        onTap: () => showChangePasswordSheet(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Settings — App
                  _SectionLabel(label: 'App'),
                  const SizedBox(height: 10),
                  _SettingCard(
                    tiles: [
                      _DarkModeSettingTile(),
                      _SettingTile(
                        icon: Icons.privacy_tip_outlined,
                        label: 'Privacy Policy',
                        iconColor: const Color(0xFF10B981),
                        onTap: () => AppUtils.launchPrivacyPolicy(context),
                      ),
                      _SettingTile(
                        icon: Icons.description_outlined,
                        label: 'Terms of Service',
                        iconColor: const Color(0xFF6366F1),
                        onTap: () => AppUtils.launchTerms(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Logout
                  _LogoutButton(isWeb: isWeb),
                  const SizedBox(height: 24),

                  // Footer
                  _VersionFooter(),
                ],
              ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sliver App Bar ────────────────────────────────────────────────────────────

class _ProfileSliverAppBar extends StatelessWidget {
  final UserModel user;
  final ApartmentModel? apt;
  final bool isCollapsed;

  const _ProfileSliverAppBar({
    required this.user,
    required this.apt,
    required this.isCollapsed,
  });

  @override
  Widget build(BuildContext context) {
    final unread = context
        .watch<NotificationProvider>()
        .unreadCount(UserRole.resident);
    return SliverAppBar(
      expandedHeight: 196,
      pinned: true,
      stretch: true,
      elevation: 0,
      automaticallyImplyLeading: false,
      backgroundColor: const Color(0xFF3D2808),
      surfaceTintColor: Colors.transparent,
      title: AnimatedOpacity(
        opacity: isCollapsed ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Text(
          user.name,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      actions: [
        SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: Colors.white),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NotificationsScreen()),
                ),
              ),
              if (unread > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: AppColors.overdue,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        unread > 9 ? '9+' : '$unread',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: _HeaderBackground(user: user, apt: apt),
      ),
    );
  }
}

// ── Header background with decorative paint ───────────────────────────────────

class _HeaderBackground extends StatelessWidget {
  final UserModel user;
  final ApartmentModel? apt;
  const _HeaderBackground({required this.user, required this.apt});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Dark navy → warm amber → gold gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF0F172A),
                Color(0xFF3D2808),
                Color(0xFFC39A51),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        // Decorative circles
        CustomPaint(painter: _HeaderPainter()),
        // Content
        SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _HeaderAvatar(initials: user.avatarInitials),
              const SizedBox(height: 10),
              Text(
                user.name,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 6),
              const _ResidentChip(),
              if (apt != null) ...[
                const SizedBox(height: 5),
                Text(
                  apt!.name,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    void circle(Offset center, double radius, double opacity) {
      canvas.drawCircle(
          center,
          radius,
          Paint()
            ..color = Colors.white.withValues(alpha: opacity)
            ..style = PaintingStyle.fill);
    }

    circle(Offset(size.width * 0.92, size.height * 0.08), 90, 0.04);
    circle(Offset(size.width * 0.08, size.height * 0.9), 65, 0.035);
    circle(Offset(size.width * 0.55, -10), 80, 0.05);
    circle(Offset(size.width * 0.75, size.height * 0.7), 40, 0.03);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Header avatar ─────────────────────────────────────────────────────────────

class _HeaderAvatar extends StatelessWidget {
  final String initials;
  const _HeaderAvatar({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFFC39A51), Color(0xFF92741A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.9), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ── Resident role chip ────────────────────────────────────────────────────────

class _ResidentChip extends StatelessWidget {
  const _ResidentChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(30),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_rounded, color: Colors.white, size: 12),
          SizedBox(width: 5),
          Text(
            'Resident',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Apartment code spotlight card ─────────────────────────────────────────────

class _ApartmentCodeCard extends StatelessWidget {
  final ApartmentModel apt;
  final BuildContext outerContext;
  const _ApartmentCodeCard({required this.apt, required this.outerContext});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5C3D10), Color(0xFFC39A51)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC39A51).withValues(alpha: 0.30),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            left: -10,
            bottom: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.vpn_key_outlined,
                          color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Apartment Code',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  apt.code,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 14),
                _CodeActionButton(
                  icon: Icons.copy_rounded,
                  label: 'Copy Code',
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: apt.code));
                    AppUtils.showSnackBar(
                        outerContext, 'Apartment code copied!',
                        color: AppColors.paid);
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

class _CodeActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _CodeActionButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.25), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Information card ──────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final UserModel user;
  final ApartmentModel? apt;
  const _InfoCard({required this.user, required this.apt});

  @override
  Widget build(BuildContext context) {
    final accent =
        RoleTheme.of(UserRole.resident).effectivePrimary(context);
    final infoRows =
        <({IconData icon, String label, String value, Color color})>[
      (
        icon: Icons.email_outlined,
        label: 'Email',
        value: user.email,
        color: accent,
      ),
      (
        icon: Icons.phone_outlined,
        label: 'Phone',
        value: user.phone.isNotEmpty ? user.phone : 'Not provided',
        color: const Color(0xFF10B981),
      ),
      if (user.unit.isNotEmpty)
        (
          icon: Icons.door_front_door_outlined,
          label: 'Flat',
          value: 'Flat ${user.unit}',
          color: AppColors.pending,
        ),
      if (apt != null) ...[
        (
          icon: Icons.apartment_outlined,
          label: 'Apartment',
          value: apt!.name,
          color: const Color(0xFF3B82F6),
        ),
        if (apt!.presidentName != null && apt!.presidentName!.isNotEmpty)
          (
            icon: Icons.shield_rounded,
            label: 'President',
            value: apt!.presidentName!,
            color: AppColors.purple,
          ),
      ],
      (
        icon: Icons.calendar_today_outlined,
        label: 'Member Since',
        value: AppUtils.formatDate(user.joinedAt),
        color: AppColors.textSecondary,
      ),
    ];

    return _Card(
      child: Column(
        children: [
          for (int i = 0; i < infoRows.length; i++) ...[
            _InfoRow(
              icon: infoRows[i].icon,
              label: infoRows[i].label,
              value: infoRows[i].value,
              color: infoRows[i].color,
            ),
            if (i < infoRows.length - 1) const _RowDivider(),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _InfoRow(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        AppTextStyles.caption(color: cs.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                  maxLines: 2,
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

// ── Quick stats ───────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final int paidCount;
  final int pendingCount;
  const _StatsRow({required this.paidCount, required this.pendingCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.check_circle_outline_rounded,
            value: paidCount,
            label: 'Paid Bills',
            color: AppColors.paid,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.hourglass_empty_rounded,
            value: pendingCount,
            label: 'Due Bills',
            color: AppColors.pending,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.receipt_long_outlined,
            value: paidCount + pendingCount,
            label: 'Total Bills',
            color: const Color(0xFF3B82F6),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  final Color color;
  const _StatCard(
      {required this.icon,
      required this.value,
      required this.label,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: value),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => Text(
              '$v',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Settings card + tile ──────────────────────────────────────────────────────

class _SettingCard extends StatelessWidget {
  final List<Widget> tiles;
  const _SettingCard({required this.tiles});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        children: [
          for (int i = 0; i < tiles.length; i++) ...[
            tiles[i],
            if (i < tiles.length - 1) const _RowDivider(),
          ],
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback onTap;

  const _SettingTile({
    required this.icon,
    required this.label,
    required this.iconColor,
    this.trailing,
    this.showChevron = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              trailing ??
                  (showChevron
                      ? Icon(Icons.chevron_right_rounded,
                          color: cs.onSurfaceVariant, size: 20)
                      : const SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }
}

class _DarkModeSettingTile extends StatelessWidget {
  const _DarkModeSettingTile();

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, tp, _) => _SettingTile(
        icon: tp.isDarkMode
            ? Icons.light_mode_outlined
            : Icons.dark_mode_outlined,
        label: 'Dark Mode',
        iconColor: tp.isDarkMode
            ? const Color(0xFFFBBF24)
            : const Color(0xFF60A5FA),
        showChevron: false,
        trailing: Switch.adaptive(
          value: tp.isDarkMode,
          onChanged: (_) => tp.toggle(),
          activeThumbColor: const Color(0xFFC39A51),
          activeTrackColor: const Color(0xFFC39A51).withValues(alpha: 0.4),
        ),
        onTap: () => tp.toggle(),
      ),
    );
  }
}

// ── Logout button ─────────────────────────────────────────────────────────────

class _LogoutButton extends StatelessWidget {
  final bool isWeb;
  const _LogoutButton({this.isWeb = false});

  @override
  Widget build(BuildContext context) {
    final btn = OutlinedButton.icon(
      onPressed: () async {
        final nav = Navigator.of(context);
        final confirm =
            await showLogoutSheet(context, UserRole.resident);
        if (confirm == true && context.mounted) {
          await context.read<AuthProvider>().logout();
          if (kIsWeb) {
            navigateToStaticLanding();
          } else {
            nav.pushReplacementNamed('/login');
          }
        }
      },
      icon: const Icon(Icons.logout_rounded,
          size: 18, color: AppColors.overdue),
      label: const Text(
        'Log Out',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.overdue,
        ),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.overdue,
        side: const BorderSide(color: AppColors.overdue, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
    if (isWeb) {
      return Center(child: SizedBox(width: 220, child: btn));
    }
    return SizedBox(width: double.infinity, child: btn);
  }
}

// ── Version footer ────────────────────────────────────────────────────────────

class _VersionFooter extends StatelessWidget {
  const _VersionFooter();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (_, snap) {
        final version = snap.hasData ? 'v${snap.data!.version}' : '';
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.apartment_rounded,
                    size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  'Maintify $version',
                  style:
                      AppTextStyles.caption(color: cs.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '© 2026 Maintify. All rights reserved.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: cs.onSurfaceVariant,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

// ── Reusable card container ───────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: child,
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Divider(
      height: 1,
      thickness: 0.8,
      color: cs.outlineVariant.withValues(alpha: 0.5),
      indent: 66,
    );
  }
}
