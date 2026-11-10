import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/community_fund_provider.dart';
import '../../models/fund_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../widgets/shimmer_loading.dart';

/// Resident read-only view of the Community Fund.
/// Shows balance, summary stats, and the full transaction list.
class CommunityFundSummaryScreen extends StatelessWidget {
  const CommunityFundSummaryScreen({super.key});

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
        subtitle:
            'Your apartment president has not set up a community fund yet.',
      );
    }

    final summary = fund.summary!;
    final txns = fund.transactions;

    return RefreshIndicator(
      color: theme.effectivePrimary(context),
      onRefresh: () async {
        await Future.delayed(const Duration(milliseconds: 400));
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Balance card
          _BalanceCard(summary: summary, theme: theme),
          const SizedBox(height: 16),

          // Stats
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Total Collected',
                  value: AppUtils.formatCurrency(summary.totalCollected),
                  color: AppColors.paid,
                  icon: Icons.trending_up_rounded,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  label: 'Total Expenses',
                  value: AppUtils.formatCurrency(summary.totalExpensed),
                  color: AppColors.overdue,
                  icon: Icons.trending_down_rounded,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Text('Transaction History',
              style: AppTextStyles.heading3(color: cs.onSurface)),
          const SizedBox(height: 10),

          if (txns.isEmpty)
            const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No Transactions Yet',
              subtitle: 'Fund transactions will appear here.',
            )
          else
            ...txns.map(
              (t) => _TxnTile(txn: t, cs: cs, isDark: isDark),
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final FundSummary summary;
  final RoleTheme theme;
  const _BalanceCard({required this.summary, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Text('Community Fund Balance',
                  style: AppTextStyles.caption(
                      color: Colors.white.withValues(alpha: 0.85))),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            AppUtils.formatCurrency(summary.balance),
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${summary.transactionCount} transaction${summary.transactionCount == 1 ? '' : 's'}  •  Read-only',
            style: AppTextStyles.caption(
                color: Colors.white.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final bool isDark;
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value,
              style: AppTextStyles.subheading(color: cs.onSurface)
                  .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style: AppTextStyles.caption(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _TxnTile extends StatelessWidget {
  final FundTransaction txn;
  final ColorScheme cs;
  final bool isDark;
  const _TxnTile({required this.txn, required this.cs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isIncome = txn.isCollection;
    final color = isIncome ? AppColors.paid : AppColors.overdue;
    final sign = isIncome ? '+' : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isIncome
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(txn.description,
                    style: AppTextStyles.bodyMedium(color: cs.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (!isIncome) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(txn.category,
                            style: AppTextStyles.caption(
                                    color: cs.onSurfaceVariant)
                                .copyWith(fontSize: 10)),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(AppUtils.formatDate(txn.createdAt),
                        style:
                            AppTextStyles.caption(color: cs.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
          Text(
            '$sign${AppUtils.formatCurrency(txn.amount)}',
            style: AppTextStyles.subheading(color: color)
                .copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
