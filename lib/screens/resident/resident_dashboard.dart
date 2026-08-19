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
import '../../providers/apartment_provider.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/apartment_header.dart';
import 'bills_screen.dart';
import 'resident_profile_screen.dart';
import 'monthly_bill_detail_screen.dart';
import '../../providers/notification_provider.dart';
import '../../providers/meeting_provider.dart';
import '../../models/meeting_model.dart';
import '../shared/notifications_screen.dart';
import '../shared/community_screen.dart';
import '../../widgets/web/web_app_shell.dart';
import '../../widgets/web/web_page_container.dart';
import '../../widgets/maintify_banner_ad.dart';

class ResidentDashboard extends StatefulWidget {
  final String? notificationType;
  const ResidentDashboard({super.key, this.notificationType});

  @override
  State<ResidentDashboard> createState() => _ResidentDashboardState();
}

class _ResidentDashboardState extends State<ResidentDashboard> {
  int _currentIndex = 0;

  static const _titles = ['Home', 'My Bills', 'Community', 'Profile'];

  late final List<Widget> _pages;

  // Maps a push notification type to the correct bottom-nav tab index.
  // bill → Bills (1); payment → Community (2); others → Home (0).
  static int _tabForType(String? type) {
    switch (type) {
      case 'bill':
        return 1;
      case 'payment':
        return 2;
      default:
        return 0;
    }
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = _tabForType(widget.notificationType);
    _pages = const [
      _ResidentHome(),
      BillsScreen(),
      CommunityScreen(),
      ResidentProfileScreen(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = RoleTheme.of(UserRole.resident);
    final cs = Theme.of(context).colorScheme;

    final isWebLayout = MediaQuery.sizeOf(context).width >= 600;
    if (isWebLayout) {
      return WebAppShell(
        role: UserRole.resident,
        navItems: const [
          WebNavItem(icon: Icons.home_outlined, label: 'Home'),
          WebNavItem(icon: Icons.receipt_outlined, label: 'My Bills'),
          WebNavItem(icon: Icons.groups_outlined, label: 'Community'),
          WebNavItem(icon: Icons.person_outlined, label: 'Profile'),
        ],
        currentIndex: _currentIndex,
        onIndexChanged: (i) => setState(() => _currentIndex = i),
        child: IndexedStack(index: _currentIndex, children: _pages),
      );
    }

    return Scaffold(
      appBar: _currentIndex == 3 ? null : _buildAppBar(theme),
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outline.withValues(alpha: 0.2), width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
          backgroundColor: Colors.transparent,
          indicatorColor: theme.secondary.withValues(alpha: 0.12),
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'Bills',
            ),
            NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups_rounded),
              label: 'Community',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(RoleTheme theme) {
    final unread = context
        .watch<NotificationProvider>()
        .unreadCount(UserRole.resident);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : cs.onSurfaceVariant;

    return AppBar(
      backgroundColor: isDark ? Colors.transparent : cs.surface,
      elevation: isDark ? 0 : 1,
      shadowColor: cs.shadow.withValues(alpha: 0.08),
      surfaceTintColor: Colors.transparent,
      title: Text(
        _titles[_currentIndex],
        style: AppTextStyles.heading3(color: isDark ? Colors.white : cs.onSurface),
      ),
      actions: [
        SizedBox(
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

}

// ── User Home ─────────────────────────────────────────────────────────────────

class _ResidentHome extends StatelessWidget {
  const _ResidentHome();

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();
    final auth = context.read<AuthProvider>();
    final billProvider = context.watch<BillProvider>();
    final aptProvider = context.watch<ApartmentProvider>();
    final theme = RoleTheme.of(UserRole.resident);
    final userId = auth.currentUser?.id ?? '';
    final user = auth.currentUser;
    final aptId = user?.apartmentId ?? '';

    if (billProvider.isInitialLoading || aptProvider.isInitialLoading) {
      return const ShimmerDashboard();
    }

    final cs = Theme.of(context).colorScheme;
    final accent = theme.effectivePrimary(context);

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

    final isWeb = MediaQuery.sizeOf(context).width >= 600;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MaintifyBannerAd(),
        ApartmentHeader(
              apartmentName: apt?.name ?? 'My Apartment',
              presidentName: apt?.presidentName ?? 'Unassigned',
              role: UserRole.resident,
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
                    color: theme.primary.withValues(alpha: 0.3),
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
                                    color: Colors.white.withValues(alpha: 0.8))),
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
                                      color: Colors.white.withValues(alpha: 0.85)),
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
                          color: Colors.white.withValues(alpha: 0.2),
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
                      color: Colors.white.withValues(alpha: 0.15),
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
                                      color: Colors.white.withValues(alpha: 0.8))),
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
                                    color: Colors.white.withValues(alpha: 0.7)),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Paid',
                                style: AppTextStyles.caption(
                                    color: Colors.white.withValues(alpha: 0.8))),
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
                  color: AppColors.overdue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppColors.overdue.withValues(alpha: 0.2)),
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
              Text('Pending Months', style: AppTextStyles.heading3(color: cs.onSurface)),
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
                  color: AppColors.paid.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: AppColors.paid.withValues(alpha: 0.2)),
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
                            style: AppTextStyles.bodySmall(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),
          ],
        );

    return RefreshIndicator(
      color: accent,
      onRefresh: () async => dashboard.refresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: isWeb
            ? WebPageContainer(maxWidth: 860, child: content)
            : Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: content,
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
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
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
          Text(label, style: AppTextStyles.caption(color: cs.onSurfaceVariant)),
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
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOverdue = summary.status == BillStatus.overdue;
    final statusColor = isOverdue ? AppColors.overdue : AppColors.pending;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResidentMonthlyBillDetailScreen(
            summary: summary,
            aptId: aptId,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: statusColor.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
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
                color: statusColor.withValues(alpha: 0.1),
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
                  Text(summary.month, style: AppTextStyles.subheading(color: cs.onSurface)),
                  Text(
                    AppUtils.formatCurrency(summary.totalAmount),
                    style: AppTextStyles.caption(color: cs.onSurface)
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
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
                Text('Mark as Paid',
                    style: AppTextStyles.caption(color: RoleTheme.of(UserRole.resident).effectivePrimary(context))),
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
        color: AppColors.purple.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.purple.withValues(alpha: 0.18)),
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
                  color: urgencyColor.withValues(alpha: 0.12),
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
              style: AppTextStyles.bodyMedium(color: Theme.of(context).colorScheme.onSurface)
                  .copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(next.description,
              style: AppTextStyles.caption(color: Theme.of(context).colorScheme.onSurfaceVariant),
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

