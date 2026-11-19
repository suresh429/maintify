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

/// Unified Community Fund screen — works for both president and resident.
///
/// Pass [role] to control visibility of write actions.
/// President sees Add Collection / Add Expense buttons.
/// Resident sees a read-only view.
class CommunityFundScreen extends StatelessWidget {
  final UserRole role;
  const CommunityFundScreen({super.key, this.role = UserRole.president});

  bool get _isPresident => role == UserRole.president;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final aptId = auth.currentUser?.apartmentId ?? '';
    final fund = context.watch<CommunityFundProvider>();
    final theme = RoleTheme.of(role);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF6F7FB),
      appBar: _buildAppBar(context, theme),
      body: fund.isLoading && fund.summary == null
          ? const ShimmerDashboard()
          : !fund.isInitialized
              ? _NotInitializedView(theme: theme, aptId: aptId, isPresident: _isPresident)
              : _FundBody(
                  fund: fund,
                  aptId: aptId,
                  theme: theme,
                  cs: cs,
                  isDark: isDark,
                  isPresident: _isPresident,
                ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, RoleTheme theme) {
    return AppBar(
      title: Text('Community Fund',
          style: AppTextStyles.heading3(color: Colors.white)),
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: theme.gradient,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        if (!_isPresident)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Read-only',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main scrollable body
// ─────────────────────────────────────────────────────────────────────────────

class _FundBody extends StatelessWidget {
  final CommunityFundProvider fund;
  final String aptId;
  final RoleTheme theme;
  final ColorScheme cs;
  final bool isDark;
  final bool isPresident;

  const _FundBody({
    required this.fund,
    required this.aptId,
    required this.theme,
    required this.cs,
    required this.isDark,
    required this.isPresident,
  });

  @override
  Widget build(BuildContext context) {
    final summary = fund.summary!;
    final recent = fund.transactions.take(5).toList();
    // Extra bottom padding so last tile doesn't hide under the fixed bar
    final bottomPad = isPresident ? 90.0 : 32.0;

    final listView = RefreshIndicator(
      color: theme.effectivePrimary(context),
      onRefresh: () async => Future.delayed(const Duration(milliseconds: 400)),
      child: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(8, 8, 8, bottomPad),
          children: [
            // ── Fund summary card (balance + stats + utilization) ──────────
            _FundSummaryCard(summary: summary, theme: theme, isDark: isDark),
            const SizedBox(height: 10),

            // ── Recent transactions header ─────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Transactions',
                    style: AppTextStyles.bodySmall(color: cs.onSurface)),
                if (fund.transactions.length > 5)
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FundTransactionsScreen(aptId: aptId),
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
                            style: AppTextStyles.caption(
                                    color: theme.effectivePrimary(context))
                                .copyWith(fontWeight: FontWeight.w600)),
                        Icon(Icons.chevron_right_rounded,
                            color: theme.effectivePrimary(context), size: 16),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Transaction list ───────────────────────────────────────────
            if (recent.isEmpty)
              EmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: 'No Transactions Yet',
                subtitle: isPresident
                    ? 'Add a collection or expense to get started.'
                    : 'No transactions have been recorded yet.',
              )
            else
              ...recent.map(
                (t) => _TxnTile(
                  txn: t,
                  cs: cs,
                  isDark: isDark,
                ),
              ),
          ],
        ),
      ),
    );

    if (!isPresident) return listView;

    return Stack(
      children: [
        listView,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : cs.surface,
                border: Border(
                  top: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _BottomActionButton(
                      label: 'Add Collection',
                      icon: Icons.add_rounded,
                      gradient: const [Color(0xFF16A34A), Color(0xFF14532D)],
                      onTap: () =>
                          showAddFundCollectionSheet(context, aptId),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BottomActionButton(
                      label: 'Add Expense',
                      icon: Icons.remove_rounded,
                      gradient: const [Color(0xFFDC2626), Color(0xFF7F1D1D)],
                      onTap: () =>
                          showAddFundExpenseSheet(context, aptId),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Not Initialized
// ─────────────────────────────────────────────────────────────────────────────

class _NotInitializedView extends StatefulWidget {
  final RoleTheme theme;
  final String aptId;
  final bool isPresident;
  const _NotInitializedView({
    required this.theme,
    required this.aptId,
    required this.isPresident,
  });

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
        AppUtils.showSnackBar(context, 'Community Fund initialized!',
            color: AppColors.paid);
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.theme.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_balance_wallet_outlined,
                  color: Colors.white, size: 52),
            ),
            const SizedBox(height: 28),
            Text('Community Fund',
                style: AppTextStyles.heading2(color: cs.onSurface)),
            const SizedBox(height: 10),
            Text(
              widget.isPresident
                  ? 'Set up a shared fund to track collections and expenses for your community.'
                  : 'Your apartment president has not set up a community fund yet.',
              style: AppTextStyles.bodyMedium(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (widget.isPresident) ...[
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
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Balance card
// ─────────────────────────────────────────────────────────────────────────────

class _FundSummaryCard extends StatelessWidget {
  final FundSummary summary;
  final RoleTheme theme;
  final bool isDark;
  const _FundSummaryCard({
    required this.summary,
    required this.theme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final pct = summary.totalCollectedPaise > 0
        ? (summary.totalExpensedPaise / summary.totalCollectedPaise)
            .clamp(0.0, 1.0)
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: theme.gradient,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.primary.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top row: icon + balance + in/out stats ────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available Balance',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppUtils.formatCurrency(summary.balance),
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _MiniStat(
                      icon: Icons.south_rounded,
                      label: 'In',
                      value: AppUtils.formatCurrency(summary.totalCollected),
                      color: Colors.white,
                    ),
                    const SizedBox(height: 6),
                    _MiniStat(
                      icon: Icons.north_rounded,
                      label: 'Out',
                      value: AppUtils.formatCurrency(summary.totalExpensed),
                      color: Colors.white,
                    ),
                  ],
                ),
              ],
            ),

            // ── Utilization bar (only when there's collected data) ─────────
            if (summary.totalCollectedPaise > 0) ...[
              const SizedBox(height: 14),
              Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Fund Utilization',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                  Text(
                    '${(pct * 100).toInt()}% spent',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 7,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withValues(alpha: pct > 0.8 ? 1.0 : 0.85),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color.withValues(alpha: 0.65)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: color.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Action button (president only)
// ─────────────────────────────────────────────────────────────────────────────

class _BottomActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;
  const _BottomActionButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.buttonText(color: Colors.white)
                    .copyWith(fontSize: 13),
              ),
            ],
          ),
        ),
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
  const _TxnTile({
    required this.txn,
    required this.cs,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = txn.isCollection;
    final color = isIncome ? AppColors.paid : AppColors.overdue;
    final sign = isIncome ? '+' : '−';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon badge
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
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

          // Description + meta
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(txn.description,
                    style: AppTextStyles.bodyMedium(color: cs.onSurface)
                        .copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (!isIncome) ...[
                      _Chip(txn.category, cs: cs),
                      const SizedBox(width: 6),
                    ],
                    _Chip(AppUtils.formatDateTime(txn.createdAt), cs: cs),
                  ],
                ),
              ],
            ),
          ),

          Text(
            '$sign${AppUtils.formatCurrency(txn.amount)}',
            style: AppTextStyles.subheading(color: color)
                .copyWith(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final ColorScheme cs;
  const _Chip(this.text, {required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(text,
          style: AppTextStyles.caption(color: cs.onSurfaceVariant)
              .copyWith(fontSize: 10)),
    );
  }
}
