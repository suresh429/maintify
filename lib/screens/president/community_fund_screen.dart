import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_fund_provider.dart';
import '../../models/fund_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../widgets/shimmer_loading.dart';
import 'add_fund_collection_screen.dart';
import 'add_fund_expense_screen.dart';
import 'fund_transactions_screen.dart';

/// President-side Community Fund main screen.
/// Shows the balance card, quick action buttons, and recent transactions.
class CommunityFundScreen extends StatelessWidget {
  const CommunityFundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final aptId = auth.currentUser?.apartmentId ?? '';
    final fund = context.watch<CommunityFundProvider>();
    final theme = RoleTheme.of(UserRole.president);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (fund.isLoading && fund.summary == null) {
      return const Scaffold(body: ShimmerDashboard());
    }

    // Not yet initialized — show setup card
    if (!fund.isInitialized) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: _NotInitializedView(theme: theme, aptId: aptId),
      );
    }

    final summary = fund.summary!;
    final recent = fund.transactions.take(5).toList();

    return Scaffold(
      backgroundColor: cs.surface,
      body: RefreshIndicator(
        color: theme.effectivePrimary(context),
        onRefresh: () async {
          // Stream auto-updates; just trigger a small delay
          await Future.delayed(const Duration(milliseconds: 400));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Balance card ────────────────────────────────────────────────
            _BalanceCard(summary: summary, theme: theme),
            const SizedBox(height: 16),

            // ── Quick actions ────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'Add Collection',
                    icon: Icons.add_circle_outline_rounded,
                    color: AppColors.paid,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddFundCollectionScreen(aptId: aptId),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    label: 'Add Expense',
                    icon: Icons.remove_circle_outline_rounded,
                    color: AppColors.overdue,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddFundExpenseScreen(aptId: aptId),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Stats row ────────────────────────────────────────────────────
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

            // ── Recent transactions ──────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Transactions',
                    style: AppTextStyles.heading3(color: cs.onSurface)),
                if (fund.transactions.length > 5)
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FundTransactionsScreen(aptId: aptId),
                      ),
                    ),
                    child: Text('View All',
                        style: AppTextStyles.caption(
                            color: theme.effectivePrimary(context))),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            if (recent.isEmpty)
              const EmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: 'No Transactions Yet',
                subtitle: 'Add a collection or expense to get started.',
              )
            else
              ...recent.map((t) => _TxnTile(txn: t, cs: cs, isDark: isDark)),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Not Initialized
// ─────────────────────────────────────────────────────────────────────────────

class _NotInitializedView extends StatefulWidget {
  final RoleTheme theme;
  final String aptId;
  const _NotInitializedView({required this.theme, required this.aptId});

  @override
  State<_NotInitializedView> createState() => _NotInitializedViewState();
}

class _NotInitializedViewState extends State<_NotInitializedView> {
  bool _loading = false;

  Future<void> _init() async {
    final auth = context.read<AuthProvider>();
    final fund = context.read<CommunityFundProvider>();
    setState(() => _loading = true);
    try {
      await fund.initializeFund(
        aptId: widget.aptId,
        createdBy: auth.currentUser?.id ?? '',
      );
      if (mounted) {
        AppUtils.showSnackBar(
          context,
          'Community Fund initialized successfully!',
          color: AppColors.paid,
        );
      }
    } catch (e) {
      if (mounted) AppUtils.showSnackBar(context, 'Failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.theme.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.account_balance_wallet_outlined,
                    color: Colors.white, size: 48),
              ),
              const SizedBox(height: 24),
              Text('Community Fund',
                  style: AppTextStyles.heading2(color: cs.onSurface)),
              const SizedBox(height: 10),
              Text(
                'Set up a shared fund to track collections and expenses for your apartment community.',
                style: AppTextStyles.bodyMedium(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _init,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.theme.effectivePrimary(context),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text('Initialize Fund',
                          style: AppTextStyles.buttonText(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Balance card
// ─────────────────────────────────────────────────────────────────────────────

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
            '${summary.transactionCount} transaction${summary.transactionCount == 1 ? '' : 's'} recorded',
            style: AppTextStyles.caption(
                color: Colors.white.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action button
// ─────────────────────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(label,
                  style: AppTextStyles.subheading(color: cs.onSurface)
                      .copyWith(fontSize: 13),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat tile
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// Transaction tile
// ─────────────────────────────────────────────────────────────────────────────

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
              isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
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
                        style: AppTextStyles.caption(color: cs.onSurfaceVariant)),
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
