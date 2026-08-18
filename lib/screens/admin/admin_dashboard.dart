import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/web_navigator.dart'
    if (dart.library.html) '../../core/utils/web_navigator_web.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../models/apartment_model.dart';
import '../../providers/apartment_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/dashboard_card.dart';
import '../../widgets/shimmer_loading.dart';
import 'apartments_screen.dart';
import 'assign_president_screen.dart';
import 'reports_screen.dart';
import '../../providers/notification_provider.dart';
import '../shared/notifications_screen.dart';
import '../../widgets/logout_sheet.dart';
import '../../widgets/web/web_app_shell.dart';
import '../../widgets/web/web_page_container.dart';

class AdminDashboard extends StatefulWidget {
  final String? notificationType;
  const AdminDashboard({super.key, this.notificationType});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;

  static const List<String> _titles = [
    'Dashboard',
    'Apartments',
    'Assign President',
    'Reports',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.notificationType == 'president_registered') {
      _currentIndex = 1;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().initialize();
    });
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 1:
        return const ApartmentsScreen();
      case 2:
        return const AssignPresidentScreen();
      case 3:
        return const ReportsScreen();
      default:
        return const _DashboardHome();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = RoleTheme.of(UserRole.admin);
    final auth = context.read<AuthProvider>();
    final cs = Theme.of(context).colorScheme;

    final isWebLayout = MediaQuery.sizeOf(context).width >= 600;
    if (isWebLayout) {
      return WebAppShell(
        role: UserRole.admin,
        navItems: const [
          WebNavItem(icon: Icons.dashboard_outlined, label: 'Dashboard'),
          WebNavItem(icon: Icons.apartment_outlined, label: 'Apartments'),
          WebNavItem(icon: Icons.manage_accounts_outlined, label: 'Assign President'),
          WebNavItem(icon: Icons.bar_chart_outlined, label: 'Reports'),
        ],
        currentIndex: _currentIndex,
        onIndexChanged: (i) => setState(() => _currentIndex = i),
        child: _buildBody(),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : cs.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark ? Colors.transparent : cs.surface,
        elevation: isDark ? 0 : 1,
        shadowColor: cs.shadow.withValues(alpha: 0.08),
        surfaceTintColor: Colors.transparent,
        title: Text(
          _titles[_currentIndex],
          style: AppTextStyles.heading3(color: isDark ? Colors.white : cs.onSurface),
        ),
        actions: [
          Consumer<ThemeProvider>(
            builder: (_, tp, __) => IconButton(
              icon: Icon(
                tp.isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                color: iconColor,
              ),
              tooltip: tp.isDarkMode ? 'Light mode' : 'Dark mode',
              onPressed: tp.toggle,
            ),
          ),
          Consumer<NotificationProvider>(
            builder: (context, notifProvider, _) {
              final unread = notifProvider.unreadCount(UserRole.admin);
              return SizedBox(
                width: 48,
                height: 48,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: Icon(Icons.notifications_outlined, color: iconColor),
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
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: 'Logout',
            onPressed: () async {
              final nav = Navigator.of(context);
              final confirm =
                  await showLogoutSheet(context, UserRole.admin);
              if (confirm == true && mounted) {
                await auth.logout();
                if (kIsWeb) {
                  navigateToStaticLanding();
                } else {
                  nav.pushReplacementNamed('/login');
                }
              }
            },
          ),
          const SizedBox(width: 8),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: theme.gradient,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outline.withValues(alpha: 0.2), width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
          backgroundColor: Colors.transparent,
          indicatorColor: theme.effectivePrimary(context).withValues(alpha: 0.15),
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.apartment_outlined),
              selectedIcon: Icon(Icons.apartment_rounded),
              label: 'Apartments',
            ),
            NavigationDestination(
              icon: Icon(Icons.manage_accounts_outlined),
              selectedIcon: Icon(Icons.manage_accounts_rounded),
              label: 'Assign',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart_rounded),
              label: 'Reports',
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dashboard home tab ────────────────────────────────────────────────────────

class _DashboardHome extends StatelessWidget {
  const _DashboardHome();

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();
    final auth = context.read<AuthProvider>();
    final theme = RoleTheme.of(UserRole.admin);
    final aptProvider = context.watch<ApartmentProvider>();

    if (aptProvider.isInitialLoading) return const ShimmerDashboard();

    final accent = theme.effectivePrimary(context);
    final isWeb = MediaQuery.sizeOf(context).width >= 600;

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning,'
        : hour < 17
            ? 'Good afternoon,'
            : 'Good evening,';

    final contentColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isWeb) ...[
          // ── Web: compact greeting row ──────────────────────────────────
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(greeting,
                      style: AppTextStyles.caption(
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  Text(
                    AppUtils.displayFirstName(auth.currentUser?.name ?? 'Admin'),
                    style: AppTextStyles.heading2(
                        color: Theme.of(context).colorScheme.onSurface),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.shield_outlined, color: accent, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Web: KPI row (4 cards) ────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _WebKpiCard(
                  label: 'Total Revenue',
                  value: AppUtils.formatCurrency(dashboard.totalRevenue),
                  icon: Icons.account_balance_wallet_outlined,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _WebKpiCard(
                  label: 'Properties',
                  value: '${dashboard.totalApartments}',
                  icon: Icons.apartment_outlined,
                  color: const Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _WebKpiCard(
                  label: 'Residents',
                  value: '${dashboard.totalResidents}',
                  icon: Icons.people_outlined,
                  color: AppColors.pending,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _WebKpiCard(
                  label: 'Presidents',
                  value: '${dashboard.totalAdmins}',
                  icon: Icons.manage_accounts_outlined,
                  color: AppColors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Web: Financial row ────────────────────────────────────────
          Text('Financial Summary',
              style: AppTextStyles.heading3(
                  color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: DashboardCard(
                  title: 'Collected',
                  value: AppUtils.formatCurrency(dashboard.totalRevenue),
                  icon: Icons.account_balance_wallet_outlined,
                  gradient: [const Color(0xFF4ADE80), const Color(0xFF16A34A)],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DashboardCard(
                  title: 'Pending',
                  value: AppUtils.formatCurrency(dashboard.pendingRevenue),
                  icon: Icons.pending_actions_outlined,
                  gradient: [const Color(0xFFFBBF24), const Color(0xFFB45309)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Web: Bills Overview ───────────────────────────────────────
          Text('Bills Overview',
              style: AppTextStyles.heading3(
                  color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'Total Bills',
                  value: '${dashboard.totalBills}',
                  icon: Icons.receipt_long_outlined,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: 'Fully Paid',
                  value: '${dashboard.paidBills}',
                  icon: Icons.check_circle_outline,
                  color: AppColors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: 'Pending',
                  value: '${dashboard.pendingBills}',
                  icon: Icons.schedule_outlined,
                  color: AppColors.pending,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  title: 'Overdue',
                  value: '${dashboard.overdueBills}',
                  icon: Icons.error_outline,
                  color: AppColors.overdue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Properties',
              style: AppTextStyles.heading3(
                  color: Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 14),
          ...aptProvider.apartments.map((apt) => _ApartmentCard(apt: apt)),
        ] else ...[
          // ── Mobile: original hero banner ───────────────────────────────
          Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: theme.gradient,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(greeting,
                            style: AppTextStyles.caption(
                                color: Colors.white.withValues(alpha: 0.8))),
                        Text(
                          AppUtils.displayFirstName(
                              auth.currentUser?.name ?? 'Admin'),
                          style:
                              AppTextStyles.heading2(color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text('Global Overview',
                            style: AppTextStyles.caption(
                                color: Colors.white.withValues(alpha: 0.8))),
                        const SizedBox(height: 6),
                        Text(
                          AppUtils.formatCurrency(dashboard.totalRevenue),
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('Total Collected Revenue',
                            style: AppTextStyles.bodySmall(
                                color: Colors.white.withValues(alpha: 0.85))),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _miniStat(
                                '${dashboard.totalApartments}', 'Properties'),
                            const SizedBox(width: 20),
                            _miniStat(
                                '${dashboard.totalResidents}', 'Residents'),
                            const SizedBox(width: 20),
                            _miniStat(
                                '${dashboard.totalAdmins}', 'Presidents'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.shield_outlined,
                        color: Colors.white, size: 36),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            Text('Financial Summary', style: AppTextStyles.heading3(color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: DashboardCard(
                    title: 'Collected',
                    value: AppUtils.formatCurrency(dashboard.totalRevenue),
                    icon: Icons.account_balance_wallet_outlined,
                    gradient: [const Color(0xFF4ADE80), const Color(0xFF16A34A)],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DashboardCard(
                    title: 'Pending',
                    value: AppUtils.formatCurrency(dashboard.pendingRevenue),
                    icon: Icons.pending_actions_outlined,
                    gradient: [const Color(0xFFFBBF24), const Color(0xFFB45309)],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            Text('Bills Overview', style: AppTextStyles.heading3(color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 14),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                StatCard(
                  title: 'Total Bills',
                  value: '${dashboard.totalBills}',
                  icon: Icons.receipt_long_outlined,
                  color: theme.effectivePrimary(context),
                ),
                StatCard(
                  title: 'Fully Paid',
                  value: '${dashboard.paidBills}',
                  icon: Icons.check_circle_outline,
                  color: AppColors.green,
                ),
                StatCard(
                  title: 'Pending',
                  value: '${dashboard.pendingBills}',
                  icon: Icons.schedule_outlined,
                  color: AppColors.pending,
                ),
                StatCard(
                  title: 'Overdue',
                  value: '${dashboard.overdueBills}',
                  icon: Icons.error_outline,
                  color: AppColors.overdue,
                ),
              ],
            ),

            const SizedBox(height: 24),
            Text('Properties', style: AppTextStyles.heading3(color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 14),

            ...aptProvider.apartments.map((apt) => _ApartmentCard(apt: apt)),

            const SizedBox(height: 20),
          ],
        ],
      );

    return RefreshIndicator(
      color: theme.effectivePrimary(context),
      onRefresh: () async => dashboard.refresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: isWeb
            ? WebPageContainer(maxWidth: 1000, child: contentColumn)
            : Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: contentColumn,
              ),
      ),
    );
  }

  Widget _miniStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            )),
        Text(label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.75),
            )),
      ],
    );
  }
}

// ── Web KPI card ─────────────────────────────────────────────────────────────

class _WebKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _WebKpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.caption(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ── Apartment card ────────────────────────────────────────────────────────────

class _ApartmentCard extends StatelessWidget {
  final ApartmentModel apt;
  const _ApartmentCard({required this.apt});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = RoleTheme.of(UserRole.admin).effectivePrimary(context);
    final adminAccent = RoleTheme.of(UserRole.president).effectivePrimary(context);
    final presidentDisplayName = apt.presidentName ?? 'Unassigned';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.apartment_outlined,
                    color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(apt.name, style: AppTextStyles.subheading(color: cs.onSurface)),
                    Text(apt.code,
                        style: AppTextStyles.caption(color: cs.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: apt.hasPresident
                      ? AppColors.green.withValues(alpha: 0.1)
                      : AppColors.overdue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  apt.hasPresident ? 'Active' : 'No President',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: apt.hasPresident
                        ? AppColors.green
                        : AppColors.overdue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _stat(Icons.door_front_door_outlined,
                  '${apt.totalFlats} Flats', adminAccent, cs),
              const SizedBox(width: 16),
              _stat(
                Icons.person_outline,
                presidentDisplayName,
                apt.hasPresident ? cs.onSurface : AppColors.overdue,
                cs,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String label, Color color, ColorScheme cs) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Flexible(
          child: Text(label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
