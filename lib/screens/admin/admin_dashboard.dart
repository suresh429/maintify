import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/bill_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../models/apartment_model.dart';
import '../../models/user_model.dart';
import '../../widgets/dashboard_card.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/apartment_header.dart';
import 'create_bill_screen.dart';
import 'manage_users_screen.dart';
import 'mark_paid_screen.dart';
import 'admin_complaints_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;

  static const _navItems = [
    _NavItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
      label: 'Home',
    ),
    _NavItem(
      icon: Icons.people_outline_rounded,
      activeIcon: Icons.people_rounded,
      label: 'Users',
    ),
    _NavItem(
      icon: Icons.check_circle_outline_rounded,
      activeIcon: Icons.check_circle_rounded,
      label: 'Mark Paid',
    ),
    _NavItem(
      icon: Icons.chat_bubble_outline_rounded,
      activeIcon: Icons.chat_bubble_rounded,
      label: 'Complaints',
    ),
  ];

  static const _titles = ['Dashboard', 'Manage Users', 'Mark Paid', 'Complaints'];

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = const [
      _AdminHome(),
      ManageUsersScreen(),
      MarkPaidScreen(),
      AdminComplaintsScreen(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = RoleTheme.of(UserRole.admin);

    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: _buildAppBar(theme),
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: _buildFloatingNav(theme),
      floatingActionButton: _currentIndex == 0 ? _buildFAB(theme) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  PreferredSizeWidget _buildAppBar(RoleTheme theme) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text(
        _titles[_currentIndex],
        style: AppTextStyles.heading3(color: Colors.white),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.logout_outlined, color: Colors.white),
          onPressed: () async {
            final confirm = await AppUtils.showConfirmDialog(
              context,
              title: 'Logout',
              message: 'Are you sure you want to logout?',
              confirmText: 'Logout',
              confirmColor: AppColors.overdue,
            );
            if (confirm == true && mounted) {
              context.read<AuthProvider>().logout();
              Navigator.pushReplacementNamed(context, '/login');
            }
          },
        ),
      ],
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: theme.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }

  Widget _buildFAB(RoleTheme theme) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: theme.gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.primary.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateBillScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Text('Create Bill',
                    style: AppTextStyles.buttonText(color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingNav(RoleTheme theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 24,
              spreadRadius: 0,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: _navItems.asMap().entries.map((e) {
            final i = e.key;
            final item = e.value;
            final isActive = _currentIndex == i;

            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _currentIndex = i),
                child: _NavTile(
                  item: item,
                  isActive: isActive,
                  activeColor: theme.primary,
                  isFirst: i == 0,
                  isLast: i == _navItems.length - 1,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Admin Home tab ────────────────────────────────────────────────────────────

class _AdminHome extends StatelessWidget {
  const _AdminHome();

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();
    final auth = context.read<AuthProvider>();
    final billProvider = context.watch<BillProvider>();
    final theme = RoleTheme.of(UserRole.admin);
    final aptId = auth.currentUser?.apartmentId ?? 'apt1';

    if (dashboard.isLoading) return const ShimmerDashboard();

    final stats = dashboard.adminStats(aptId);
    final apt = MockApartments.findById(aptId);
    final president = MockUsers.presidentFor(aptId);
    final recentBills = billProvider.billsForApartment(aptId).take(5).toList();

    return RefreshIndicator(
      color: theme.primary,
      onRefresh: () async => dashboard.refresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ApartmentHeader(
              apartmentName: apt?.name ?? 'My Apartment',
              presidentName:
                  president?.name ?? auth.currentUser?.name ?? 'You',
              role: UserRole.admin,
            ),

            // Hero banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: theme.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Good morning,',
                                style: AppTextStyles.caption(
                                    color: Colors.white.withOpacity(0.8))),
                            Text(
                              auth.currentUser?.name.split(' ').first ??
                                  'Admin',
                              style:
                                  AppTextStyles.heading2(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.manage_accounts_outlined,
                            color: Colors.white, size: 28),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _HeroBannerStat(
                            label: 'Collected',
                            value: AppUtils.formatCurrency(
                                stats['collected'] as double),
                            icon: Icons.trending_up,
                          ),
                        ),
                        Container(
                            width: 1,
                            height: 36,
                            color: Colors.white.withOpacity(0.2)),
                        Expanded(
                          child: _HeroBannerStat(
                            label: 'Pending',
                            value: AppUtils.formatCurrency(
                                stats['pending'] as double),
                            icon: Icons.schedule_outlined,
                          ),
                        ),
                        Container(
                            width: 1,
                            height: 36,
                            color: Colors.white.withOpacity(0.2)),
                        Expanded(
                          child: _HeroBannerStat(
                            label: 'Residents',
                            value: '${stats['totalResidents']}',
                            icon: Icons.people_outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            Text('Quick Stats', style: AppTextStyles.heading3()),
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
                  value: '${stats['totalBills']}',
                  icon: Icons.receipt_long_outlined,
                  color: theme.primary,
                ),
                StatCard(
                  title: 'Fully Paid',
                  value: '${stats['paidBills']}',
                  icon: Icons.check_circle_outline,
                  color: AppColors.green,
                ),
                StatCard(
                  title: 'Pending',
                  value: '${stats['pendingBills']}',
                  icon: Icons.schedule_outlined,
                  color: AppColors.pending,
                ),
                StatCard(
                  title: 'Overdue',
                  value: '${stats['overdueBills']}',
                  icon: Icons.error_outline,
                  color: AppColors.overdue,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Collection progress
            Container(
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Collection Rate',
                          style: AppTextStyles.subheading()),
                      Text(
                        '${((stats['collectionRate'] as double) * 100).toInt()}%',
                        style:
                            AppTextStyles.subheading(color: theme.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: stats['collectionRate'] as double,
                      backgroundColor: AppColors.lightGray,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(theme.primary),
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${stats['paidPayments']} of ${stats['totalPayments']} payments collected',
                        style: AppTextStyles.caption(),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (stats['collectionRate'] as double) > 0.7
                              ? AppColors.green.withOpacity(0.1)
                              : AppColors.pending.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          (stats['collectionRate'] as double) > 0.7
                              ? 'On Track'
                              : 'Needs Attention',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color:
                                (stats['collectionRate'] as double) > 0.7
                                    ? AppColors.green
                                    : AppColors.pending,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            Text('Recent Bills', style: AppTextStyles.heading3()),
            const SizedBox(height: 14),

            if (recentBills.isEmpty)
              const EmptyState(
                title: 'No Bills Yet',
                subtitle: 'Tap "Create Bill" to add a bill',
                icon: Icons.receipt_long_outlined,
              )
            else
              ...recentBills.map((bill) {
                final payments = billProvider.paymentsForBill(bill.id);
                final paidCount = bill.paidFlats(payments);
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(bill.title,
                                style: AppTextStyles.subheading(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 3),
                            Text(
                              '${AppUtils.formatCurrency(bill.totalAmount)} · ${bill.totalFlats} flats · ${AppUtils.formatCurrency(bill.perFlatShare)}/flat',
                              style: AppTextStyles.caption(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Due: ${AppUtils.formatDate(bill.dueDate)}',
                              style: AppTextStyles.caption(),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$paidCount/${bill.totalFlats}',
                            style: AppTextStyles.subheading(
                                color: theme.primary),
                          ),
                          Text('paid', style: AppTextStyles.caption()),
                        ],
                      ),
                    ],
                  ),
                );
              }),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _HeroBannerStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _HeroBannerStat(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 14,
            )),
        Text(label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 10,
              color: Colors.white.withOpacity(0.7),
            )),
      ],
    );
  }
}

// ── Shared nav components ─────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem(
      {required this.icon,
      required this.activeIcon,
      required this.label});
}

class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool isActive;
  final Color activeColor;
  final bool isFirst;
  final bool isLast;

  const _NavTile({
    required this.item,
    required this.isActive,
    required this.activeColor,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      margin: EdgeInsets.fromLTRB(
        isFirst ? 6 : 2,
        6,
        isLast ? 6 : 2,
        6,
      ),
      decoration: BoxDecoration(
        color: isActive ? activeColor.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              isActive ? item.activeIcon : item.icon,
              key: ValueKey(isActive),
              color: isActive ? activeColor : const Color(0xFF94A3B8),
              size: 22,
            ),
          ),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive ? activeColor : const Color(0xFF94A3B8),
            ),
            child: Text(item.label),
          ),
        ],
      ),
    );
  }
}
