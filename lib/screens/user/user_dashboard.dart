import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bill_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../models/bill_model.dart';
import '../../models/user_model.dart';
import '../../providers/apartment_provider.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/apartment_header.dart';
import 'bills_screen.dart';
import 'payment_history_screen.dart';
import 'user_profile_screen.dart';
import 'monthly_bill_detail_screen.dart';
import '../../providers/notification_provider.dart';
import '../../providers/meeting_provider.dart';
import '../../models/meeting_model.dart';
import '../shared/notifications_screen.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  int _currentIndex = 0;

  static const _navItems = [
    _NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    _NavItem(
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long_rounded,
      label: 'Bills',
    ),
    _NavItem(
      icon: Icons.history_outlined,
      activeIcon: Icons.history_rounded,
      label: 'Payments',
    ),
    _NavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  static const _titles = ['Home', 'My Bills', 'Payments', 'Profile'];

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = const [
      _UserHome(),
      BillsScreen(),
      PaymentHistoryScreen(),
      UserProfileScreen(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = RoleTheme.of(UserRole.user);

    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: _buildAppBar(theme),
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: _buildFloatingNav(theme),
    );
  }

  PreferredSizeWidget _buildAppBar(RoleTheme theme) {
    final unread = context
        .watch<NotificationProvider>()
        .unreadCount(UserRole.user);
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text(
        _titles[_currentIndex],
        style: AppTextStyles.heading3(color: Colors.white),
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
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: theme.gradient,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingNav(RoleTheme theme) {
    final sysNavHeight = MediaQuery.of(context).viewPadding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + sysNavHeight),
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
                  activeColor: theme.secondary,
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

// ── User Home ─────────────────────────────────────────────────────────────────

class _UserHome extends StatelessWidget {
  const _UserHome();

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();
    final auth = context.read<AuthProvider>();
    final billProvider = context.watch<BillProvider>();
    final aptProvider = context.watch<ApartmentProvider>();
    final theme = RoleTheme.of(UserRole.user);
    final userId = auth.currentUser?.id ?? '';
    final user = auth.currentUser;
    final aptId = user?.apartmentId ?? '';

    if (billProvider.isInitialLoading || aptProvider.isInitialLoading) {
      return const ShimmerDashboard();
    }

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning,'
        : hour < 17
            ? 'Good afternoon,'
            : 'Good evening,';

    final allViews = billProvider.userBillViews(userId);
    final allMonthlySummaries = billProvider.userMonthlySummaries(userId);
    final pendingMonths =
        allMonthlySummaries.where((s) => !s.isFullyPaid).toList();
    final overdueViews = allViews.where((v) => v.payment.isOverdue).toList();
    final totalDue = billProvider.totalDueForUser(userId);
    final totalPaid = billProvider.totalPaidForUser(userId);

    final apt = aptProvider.findById(aptId);
    final upcomingMeetings =
        context.watch<MeetingProvider>().upcomingMeetings(aptId);

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
              presidentName: apt?.presidentName ?? 'Unassigned',
              role: UserRole.user,
            ),

            // Hero card
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
                    color: theme.primary.withOpacity(0.3),
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
                            Text(greeting,
                                style: AppTextStyles.bodySmall(
                                    color: Colors.white.withOpacity(0.8))),
                            Text(
                              AppUtils.displayFirstName(
                                  user?.name ?? 'Resident'),
                              style:
                                  AppTextStyles.heading2(color: Colors.white),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.door_front_door_outlined,
                                    color: Colors.white70, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  'Unit ${user?.unit ?? '101'}',
                                  style: AppTextStyles.bodySmall(
                                      color: Colors.white.withOpacity(0.85)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(
                            user?.avatarInitials ?? 'RV',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total Due',
                                  style: AppTextStyles.caption(
                                      color: Colors.white.withOpacity(0.8))),
                              const SizedBox(height: 4),
                              Text(
                                AppUtils.formatCurrency(totalDue),
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 26,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${pendingMonths.length} month${pendingMonths.length != 1 ? 's' : ''} pending',
                                style: AppTextStyles.caption(
                                    color: Colors.white.withOpacity(0.7)),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Paid',
                                style: AppTextStyles.caption(
                                    color: Colors.white.withOpacity(0.8))),
                            const SizedBox(height: 4),
                            Text(
                              AppUtils.formatCurrency(totalPaid),
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (overdueViews.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.overdue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppColors.overdue.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: AppColors.overdue, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${overdueViews.length} bill${overdueViews.length != 1 ? 's are' : ' is'} overdue! Pay now to avoid penalties.',
                        style:
                            AppTextStyles.bodySmall(color: AppColors.overdue),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (upcomingMeetings.isNotEmpty) ...[
              const SizedBox(height: 16),
              _UpcomingMeetingsBanner(
                  meetings: upcomingMeetings, theme: theme),
            ],

            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: _QuickStat(
                    label: 'Pending',
                    value: '${pendingMonths.length}',
                    color: AppColors.pending,
                    icon: Icons.schedule_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickStat(
                    label: 'Paid',
                    value:
                        '${allMonthlySummaries.where((s) => s.isFullyPaid).length}',
                    color: AppColors.paid,
                    icon: Icons.check_circle_outline,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickStat(
                    label: 'Overdue',
                    value: '${overdueViews.length}',
                    color: AppColors.overdue,
                    icon: Icons.error_outline,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            if (pendingMonths.isNotEmpty) ...[
              Text('Pending Months', style: AppTextStyles.heading3()),
              const SizedBox(height: 14),
              ...pendingMonths.take(3).map((s) => _PendingMonthCard(
                    summary: s,
                    aptId: aptId,
                    theme: theme,
                  )),
            ] else
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.paid.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: AppColors.paid.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.paid, size: 32),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('All Clear!',
                            style: AppTextStyles.subheading(
                                color: AppColors.paid)),
                        Text('No pending bills. Great job!',
                            style: AppTextStyles.bodySmall()),
                      ],
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _QuickStat(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: color,
              )),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.caption()),
        ],
      ),
    );
  }
}

class _PendingMonthCard extends StatelessWidget {
  final UserMonthlySummary summary;
  final String aptId;
  final RoleTheme theme;

  const _PendingMonthCard({
    required this.summary,
    required this.aptId,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final isOverdue = summary.status == BillStatus.overdue;
    final statusColor = isOverdue ? AppColors.overdue : AppColors.pending;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserMonthlyBillDetailScreen(
            summary: summary,
            aptId: aptId,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: statusColor.withOpacity(0.2)),
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
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.calendar_month_outlined,
                  color: statusColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(summary.month, style: AppTextStyles.subheading()),
                  Text(
                    AppUtils.formatCurrency(summary.totalAmount),
                    style:
                        AppTextStyles.caption(color: AppColors.textPrimary)
                            .copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Due: ${AppUtils.formatDate(summary.dueDate)}',
                    style: AppTextStyles.caption(color: statusColor),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isOverdue ? 'Overdue' : 'Pending',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text('Pay Now',
                    style: AppTextStyles.caption(color: theme.primary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Upcoming meetings banner ──────────────────────────────────────────────────

class _UpcomingMeetingsBanner extends StatelessWidget {
  final List<MeetingModel> meetings;
  final RoleTheme theme;

  const _UpcomingMeetingsBanner(
      {required this.meetings, required this.theme});

  String _formatDateTime(DateTime dt) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '${dt.day} ${months[dt.month]}  ·  $hour:$min $period';
  }

  @override
  Widget build(BuildContext context) {
    final next = meetings.first;
    final days = next.scheduledAt.difference(DateTime.now()).inDays;
    final urgency = days == 0
        ? 'Today'
        : days == 1
            ? 'Tomorrow'
            : 'In $days days';
    final urgencyColor = days <= 1 ? AppColors.overdue : AppColors.purple;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.purple.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.purple.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_rounded,
                  color: AppColors.purple, size: 18),
              const SizedBox(width: 6),
              Text(
                'Upcoming Meeting',
                style: AppTextStyles.subheading(color: AppColors.purple),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: urgencyColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  urgency,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: urgencyColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(next.title,
              style: AppTextStyles.bodyMedium(color: AppColors.textPrimary)
                  .copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(next.description,
              style: AppTextStyles.caption(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.schedule_outlined,
                  size: 13, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                _formatDateTime(next.scheduledAt),
                style: AppTextStyles.caption(color: AppColors.textSecondary),
              ),
              if (meetings.length > 1) ...[
                const Spacer(),
                Text(
                  '+${meetings.length - 1} more',
                  style: AppTextStyles.caption(color: AppColors.purple),
                ),
              ],
            ],
          ),
        ],
      ),
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
