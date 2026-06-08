import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../models/apartment_model.dart';
import '../../models/user_model.dart';
import '../../widgets/dashboard_card.dart';
import '../../widgets/shimmer_loading.dart';
import 'apartments_screen.dart';
import 'assign_president_screen.dart';
import 'reports_screen.dart';
import '../../providers/notification_provider.dart';
import '../shared/notifications_screen.dart';
import '../../widgets/logout_sheet.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  int _drawerIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const List<Map<String, dynamic>> _navItems = [
    {'label': 'Dashboard', 'icon': Icons.dashboard_outlined},
    {'label': 'Apartments', 'icon': Icons.apartment_outlined},
    {'label': 'Assign President', 'icon': Icons.manage_accounts_outlined},
    {'label': 'Reports', 'icon': Icons.bar_chart_outlined},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().initialize();
    });
  }

  Widget _buildBody() {
    switch (_drawerIndex) {
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
    final theme = RoleTheme.of(UserRole.superAdmin);
    final auth = context.read<AuthProvider>();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(
          _navItems[_drawerIndex]['label'],
          style: AppTextStyles.heading3(color: Colors.white),
        ),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, notifProvider, _) {
              final unread =
                  notifProvider.unreadCount(UserRole.superAdmin);
              return SizedBox(
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
              );
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
      drawer: _buildDrawer(theme, auth),
      body: _buildBody(),
    );
  }

  Widget _buildDrawer(RoleTheme theme, AuthProvider auth) {
    final user = auth.currentUser;
    return Drawer(
      child: Column(
        children: [
          // ── Gradient header ───────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: theme.gradient,
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Circle avatar with initials
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withOpacity(0.4), width: 2),
                  ),
                  child: Center(
                    child: Text(
                      user?.avatarInitials ?? 'SA',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  user?.name ?? 'Super Admin',
                  style: AppTextStyles.subheading(color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  user?.email ?? '',
                  style: AppTextStyles.caption(
                      color: Colors.white.withOpacity(0.75)),
                ),
                const SizedBox(height: 10),
                // Role badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.35), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield_outlined,
                          color: Colors.white, size: 13),
                      const SizedBox(width: 5),
                      const Text(
                        'Super Admin',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Nav items ─────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                ..._navItems.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  final isSelected = _drawerIndex == i;
                  return Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 3),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.primary.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Icon(
                        item['icon'],
                        color: isSelected
                            ? theme.primary
                            : AppColors.textSecondary,
                        size: 22,
                      ),
                      title: Text(
                        item['label'],
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSelected
                              ? theme.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onTap: () {
                        setState(() => _drawerIndex = i);
                        Navigator.pop(context);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),

          const Divider(height: 1),
          ListTile(
            leading:
                const Icon(Icons.logout_rounded, color: AppColors.overdue),
            title: Text('Logout',
                style: AppTextStyles.bodyLarge(color: AppColors.overdue)),
            onTap: () async {
              final confirm =
                  await showLogoutSheet(context, UserRole.superAdmin);
              if (confirm == true && mounted) {
                context.read<AuthProvider>().logout();
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
          const SizedBox(height: 12),
        ],
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
    final theme = RoleTheme.of(UserRole.superAdmin);

    if (dashboard.isLoading) return const ShimmerDashboard();

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning,'
        : hour < 17
            ? 'Good afternoon,'
            : 'Good evening,';

    return RefreshIndicator(
      color: theme.primary,
      onRefresh: () async => dashboard.refresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero banner
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
                    color: theme.primary.withOpacity(0.25),
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
                                color: Colors.white.withOpacity(0.8))),
                        Text(
                          AppUtils.displayFirstName(
                              auth.currentUser?.name ?? 'Admin'),
                          style:
                              AppTextStyles.heading2(color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text('Global Overview',
                            style: AppTextStyles.caption(
                                color: Colors.white.withOpacity(0.8))),
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
                                color: Colors.white.withOpacity(0.85))),
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
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.shield_outlined,
                        color: Colors.white, size: 36),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            Text('Financial Summary', style: AppTextStyles.heading3()),
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
            Text('Bills Overview', style: AppTextStyles.heading3()),
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
                  color: theme.primary,
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
            Text('Properties', style: AppTextStyles.heading3()),
            const SizedBox(height: 14),

            ...MockApartments.all.map((apt) => _ApartmentCard(apt: apt)),

            const SizedBox(height: 20),
          ],
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
              color: Colors.white.withOpacity(0.75),
            )),
      ],
    );
  }
}

class _ApartmentCard extends StatelessWidget {
  final ApartmentModel apt;
  const _ApartmentCard({required this.apt});

  @override
  Widget build(BuildContext context) {
    final president = MockUsers.presidentFor(apt.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.apartment_outlined,
                    color: AppColors.purple, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(apt.name, style: AppTextStyles.subheading()),
                    Text('${apt.address}, ${apt.city}',
                        style: AppTextStyles.caption(),
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
                      ? AppColors.green.withOpacity(0.1)
                      : AppColors.overdue.withOpacity(0.1),
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
                  '${apt.totalFlats} Flats', AppColors.blue),
              const SizedBox(width: 16),
              _stat(
                Icons.person_outline,
                president?.name ?? 'Unassigned',
                apt.hasPresident
                    ? AppColors.textPrimary
                    : AppColors.overdue,
              ),
            ],
          ),
          if (apt.amenities.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: apt.amenities
                  .take(4)
                  .map((a) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.lightGray,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(a,
                            style: AppTextStyles.caption(
                                color: AppColors.textSecondary)),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String label, Color color) {
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
