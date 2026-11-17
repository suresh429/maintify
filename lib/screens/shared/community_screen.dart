import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../providers/community_fund_provider.dart';
import '../../widgets/maintify_banner_ad.dart';
import '../../widgets/shimmer_loading.dart';
import '../president/community_fund_screen.dart';
import '../resident/complaints_screen.dart';
import '../resident/directory_screen.dart';
import 'payment_board_screen.dart';

/// Community screen — four tabs: Payment Board, Complaints, Directory, Fund.
class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = RoleTheme.of(UserRole.resident);
    final accent = theme.effectivePrimary(context);
    final cs = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: MaintifyBannerAd(),
          ),
          // TabBar
          Container(
            color: cs.surface,
            child: TabBar(
              labelColor: accent,
              unselectedLabelColor: cs.onSurfaceVariant,
              indicatorColor: accent,
              indicatorWeight: 2.5,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelStyle: AppTextStyles.caption(color: accent)
                  .copyWith(fontWeight: FontWeight.w600, fontSize: 11),
              unselectedLabelStyle:
                  AppTextStyles.caption(color: cs.onSurfaceVariant)
                      .copyWith(fontSize: 11),
              dividerColor: cs.outlineVariant.withValues(alpha: 0.4),
              tabs: const [
                Tab(
                  icon: Icon(Icons.receipt_long_outlined, size: 18),
                  text: 'Payment Board',
                  iconMargin: EdgeInsets.only(bottom: 4),
                ),
                Tab(
                  icon: Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  text: 'Complaints',
                  iconMargin: EdgeInsets.only(bottom: 4),
                ),
                Tab(
                  icon: Icon(Icons.people_outline_rounded, size: 18),
                  text: 'Directory',
                  iconMargin: EdgeInsets.only(bottom: 4),
                ),
                Tab(
                  icon: Icon(Icons.account_balance_wallet_outlined, size: 18),
                  text: 'Fund',
                  iconMargin: EdgeInsets.only(bottom: 4),
                ),
              ],
            ),
          ),
          Divider(
              height: 1,
              color: cs.outlineVariant.withValues(alpha: 0.4)),

          // Tab views
          const Expanded(
            child: TabBarView(
              children: [
                PaymentBoardScreen(),
                _CommunityComplaintView(),
                DirectoryScreen(),
                _FundTabView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Wraps ComplaintsScreen inside the community tab.
/// ComplaintsScreen manages its own FAB and empty state.
class _CommunityComplaintView extends StatelessWidget {
  const _CommunityComplaintView();

  @override
  Widget build(BuildContext context) {
    return const ComplaintsScreen();
  }
}

/// Fund tab preview — shows balance summary and navigates to the full
/// CommunityFundScreen on tap.
class _FundTabView extends StatelessWidget {
  const _FundTabView();

  @override
  Widget build(BuildContext context) {
    final fund = context.watch<CommunityFundProvider>();
    final theme = RoleTheme.of(UserRole.resident);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (fund.isLoading && fund.summary == null) {
      return const ShimmerDashboard();
    }

    if (!fund.isInitialized) {
      return const EmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: 'No Fund Yet',
        subtitle: 'Your president has not set up a community fund yet.',
      );
    }

    final summary = fund.summary!;
    final accent = theme.effectivePrimary(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        // ── Tappable balance card → navigates to full screen ──────────────
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CommunityFundScreen(role: UserRole.resident),
            ),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: theme.gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
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
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text('Available Balance',
                        style: AppTextStyles.caption(
                            color: Colors.white.withValues(alpha: 0.85))),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Text('View Details',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              )),
                          const SizedBox(width: 2),
                          const Icon(Icons.arrow_forward_ios_rounded,
                              color: Colors.white, size: 10),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  AppUtils.formatCurrency(summary.balance),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Divider(color: Colors.white.withValues(alpha: 0.2), height: 20),
                Row(
                  children: [
                    _MiniStat(
                        label: 'Collected',
                        value: AppUtils.formatCurrency(summary.totalCollected)),
                    Container(
                      width: 1,
                      height: 28,
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                    _MiniStat(
                        label: 'Spent',
                        value: AppUtils.formatCurrency(summary.totalExpensed)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${summary.transactionCount} txns',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Utilization bar ───────────────────────────────────────────────
        if (summary.totalCollectedPaise > 0) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
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
                    Text('Fund Utilization',
                        style: AppTextStyles.subheading(color: cs.onSurface)
                            .copyWith(fontSize: 13)),
                    Text(
                      '${((summary.totalExpensedPaise / summary.totalCollectedPaise) * 100).clamp(0, 100).toInt()}% spent',
                      style: AppTextStyles.caption(color: accent)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (summary.totalExpensedPaise /
                            summary.totalCollectedPaise)
                        .clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: AppColors.paid
                        .withValues(alpha: isDark ? 0.15 : 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      (summary.totalExpensedPaise /
                                  summary.totalCollectedPaise) >
                              0.8
                          ? AppColors.overdue
                          : AppColors.paid,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── Recent transactions preview ───────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Transactions',
                style: AppTextStyles.bodySmall(color: cs.onSurface)),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const CommunityFundScreen(role: UserRole.resident),
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                children: [
                  Text('View All',
                      style: AppTextStyles.caption(color: accent)
                          .copyWith(fontWeight: FontWeight.w600)),
                  Icon(Icons.chevron_right_rounded, color: accent, size: 16),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (fund.transactions.isEmpty)
          const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No Transactions Yet',
            subtitle: 'Fund transactions will appear here.',
          )
        else
          ...fund.transactions.take(3).map(
            (t) {
              final isIncome = t.isCollection;
              final color = isIncome ? AppColors.paid : AppColors.overdue;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: isDark ? 0.2 : 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isIncome
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        color: color,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.description,
                              style: AppTextStyles.bodyMedium(
                                      color: cs.onSurface)
                                  .copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text(AppUtils.formatDate(t.createdAt),
                              style: AppTextStyles.caption(
                                  color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    Text(
                      '${isIncome ? '+' : '−'}${AppUtils.formatCurrency(t.amount)}',
                      style: AppTextStyles.subheading(color: color)
                          .copyWith(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 10,
              color: Colors.white70,
            )),
        Text(value,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            )),
      ],
    );
  }
}
