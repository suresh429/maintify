import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/bill_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../providers/apartment_provider.dart';
import '../../widgets/dashboard_card.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/apartment_header.dart';
import 'create_bill_screen.dart';
import 'manage_users_screen.dart';
import 'mark_paid_screen.dart';
import 'admin_complaints_screen.dart';
import 'resident_requests_screen.dart';
import 'admin_profile_screen.dart';
import '../../widgets/schedule_meeting_sheet.dart';
import '../../providers/notification_provider.dart';
import '../../providers/meeting_provider.dart';
import '../../providers/registration_provider.dart';
import '../../models/meeting_model.dart';
import '../../models/bill_model.dart';
import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../shared/notifications_screen.dart';
import 'edit_bill_sheet.dart';

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
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long_rounded,
      label: 'Bills',
    ),
    _NavItem(
      icon: Icons.chat_bubble_outline_rounded,
      activeIcon: Icons.chat_bubble_rounded,
      label: 'Complaints',
    ),
  ];

  static const _titles = ['Dashboard', 'Manage Users', 'Bills', 'Complaints'];

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
    final unread =
        context.watch<NotificationProvider>().unreadCount(UserRole.admin);
    final user = context.read<AuthProvider>().currentUser;

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text(
        _titles[_currentIndex],
        style: AppTextStyles.heading3(color: Colors.white),
      ),
      actions: [
        // Notification bell
        SizedBox(
          width: 44,
          height: 44,
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
        // Profile avatar
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const AdminProfileScreen()),
            ),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2),
                border: Border.all(
                    color: Colors.white.withOpacity(0.7), width: 1.5),
              ),
              child: Center(
                child: Text(
                  user?.avatarInitials ?? 'A',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ),
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

  Widget _buildFAB(RoleTheme theme) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: theme.gradient,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
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
    // viewPadding.bottom is the system navigation bar height (3-button nav ~48 dp,
    // gesture nav 0–15 dp).  Unlike padding.bottom, viewPadding is NOT zeroed-out
    // by Scaffold, so we must add it here to keep the floating nav above the bar.
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
    final aptProvider = context.watch<ApartmentProvider>();
    final theme = RoleTheme.of(UserRole.admin);
    final aptId = auth.currentUser?.apartmentId ?? '';

    if (billProvider.isInitialLoading || aptProvider.isInitialLoading) {
      return const ShimmerDashboard();
    }

    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning,'
        : hour < 17
            ? 'Good afternoon,'
            : 'Good evening,';

    final stats = dashboard.adminStats(aptId);
    final apt = aptProvider.findById(aptId);
    final recentBills = billProvider.billsForApartment(aptId).take(5).toList();
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
              presidentName:
                  apt?.presidentName ?? auth.currentUser?.name ?? 'You',
              role: UserRole.admin,
            ),

            // Hero banner
            Container(
              padding: const EdgeInsets.all(20),
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
                                style: AppTextStyles.caption(
                                    color: Colors.white.withOpacity(0.8))),
                            Text(
                              AppUtils.displayFirstName(
                                  auth.currentUser?.name ?? 'Admin'),
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

            const SizedBox(height: 20),

            // ── Resident Requests (priority card) ────────────────────────
            Consumer<RegistrationProvider>(
              builder: (_, reg, __) {
                final count = reg.pendingRequests.length;
                final hasPending = count > 0;
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ResidentRequestsScreen()),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: hasPending
                          ? AppColors.blue.withOpacity(0.06)
                          : AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: hasPending
                          ? Border.all(
                              color: AppColors.blue.withOpacity(0.35),
                              width: 1.5)
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: hasPending
                                ? AppColors.blue.withOpacity(0.12)
                                : AppColors.lightGray,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            Icons.person_add_alt_1_outlined,
                            color: hasPending
                                ? AppColors.blue
                                : AppColors.textSecondary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Resident Requests',
                                  style: AppTextStyles.subheading()),
                              const SizedBox(height: 1),
                              Text(
                                hasPending
                                    ? '$count pending · Approve new residents'
                                    : 'No pending requests',
                                style: AppTextStyles.caption(
                                  color: hasPending
                                      ? AppColors.blue
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (hasPending)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.blue,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: hasPending
                              ? AppColors.blue
                              : AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            // ── Schedule Meeting action card ──────────────────────────────
            GestureDetector(
              onTap: () async {
                final scheduled =
                    await showScheduleMeetingSheet(context);
                if (scheduled && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                          'Meeting scheduled! All members notified.'),
                      backgroundColor: theme.primary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
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
                        color: AppColors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.event_rounded,
                          color: AppColors.purple, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Schedule Meeting',
                              style: AppTextStyles.subheading()),
                          Text(
                              'Notify all flat members about an upcoming meeting',
                              style: AppTextStyles.caption()),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),

            // Upcoming meetings section
            if (upcomingMeetings.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Upcoming Meetings', style: AppTextStyles.heading3()),
              const SizedBox(height: 14),
              ...upcomingMeetings.map((m) => _MeetingCard(
                    meeting: m,
                    theme: theme,
                  )),
            ],

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
                final rawBill =
                    billProvider.rawBillById(bill.id) ?? bill;
                final residents = context
                    .read<UserProvider>()
                    .membersForApartment(aptId);
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
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
                      GestureDetector(
                        onTap: () => _showBillActionsSheet(
                          context,
                          bill: rawBill,
                          billMonth: bill.month,
                          residents: residents,
                          billProvider: billProvider,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: const Icon(Icons.more_vert_rounded,
                              size: 20, color: AppColors.textSecondary),
                        ),
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

// ── Meeting card ──────────────────────────────────────────────────────────────

class _MeetingCard extends StatelessWidget {
  final MeetingModel meeting;
  final RoleTheme theme;

  const _MeetingCard({required this.meeting, required this.theme});

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
    return '${dt.day} ${months[dt.month]} ${dt.year}  ·  $hour:$min $period';
  }

  int get _daysUntil =>
      meeting.scheduledAt.difference(DateTime.now()).inDays;

  @override
  Widget build(BuildContext context) {
    final days = _daysUntil;
    final urgency = days == 0
        ? 'Today'
        : days == 1
            ? 'Tomorrow'
            : 'In $days days';
    final urgencyColor = days <= 1 ? AppColors.overdue : AppColors.purple;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.purple.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.event_rounded,
                color: AppColors.purple, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meeting.title,
                    style: AppTextStyles.subheading(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(meeting.description,
                    style: AppTextStyles.caption(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.schedule_outlined,
                        size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _formatDateTime(meeting.scheduledAt),
                        style: AppTextStyles.caption(
                            color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: urgencyColor.withOpacity(0.1),
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

// ── Bill actions sheet ────────────────────────────────────────────────────────

void _showBillActionsSheet(
  BuildContext context, {
  required BillModel bill,
  required String billMonth,
  required List<UserModel> residents,
  required BillProvider billProvider,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  _dashboardActionTile(
                    icon: Icons.edit_outlined,
                    title: 'Edit Bill',
                    subtitle: 'Update categories, amounts or due date',
                    color: AppColors.blue,
                    onTap: () {
                      Navigator.pop(context);
                      showEditBillSheet(context,
                          bill: bill, residents: residents);
                    },
                  ),
                  const SizedBox(height: 10),
                  _dashboardActionTile(
                    icon: Icons.delete_outline_rounded,
                    title: 'Delete Bill',
                    subtitle: 'Permanently remove bill and all payments',
                    color: AppColors.overdue,
                    onTap: () {
                      Navigator.pop(context);
                      _confirmDeleteBill(context,
                          billId: bill.id,
                          billMonth: billMonth,
                          billProvider: billProvider);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _dashboardActionTile({
  required IconData icon,
  required String title,
  required String subtitle,
  required Color color,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
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
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, color: color, size: 14),
        ],
      ),
    ),
  );
}

void _confirmDeleteBill(
  BuildContext context, {
  required String billId,
  required String billMonth,
  required BillProvider billProvider,
}) {
  showDialog<bool>(
    context: context,
    builder: (_) => Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.overdue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_rounded,
                  color: AppColors.overdue, size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'Delete Bill?',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'This will permanently delete the $billMonth bill and all payment records. This cannot be undone.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(fontFamily: 'Poppins')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.overdue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Delete',
                        style: TextStyle(
                            fontFamily: 'Poppins', color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  ).then((confirmed) async {
    if (confirmed != true) return;
    if (!context.mounted) return;
    await billProvider.adminDeleteBill(billId);
    if (!context.mounted) return;
    AppUtils.showSnackBar(context, '$billMonth bill deleted');
  });
}
