import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/community_fund_provider.dart';
import '../../models/fund_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../widgets/shimmer_loading.dart';

/// Full transaction history — president can delete individual entries.
class FundTransactionsScreen extends StatefulWidget {
  final String aptId;
  const FundTransactionsScreen({super.key, required this.aptId});

  @override
  State<FundTransactionsScreen> createState() => _FundTransactionsScreenState();
}

class _FundTransactionsScreenState extends State<FundTransactionsScreen> {
  String _filter = 'all'; // 'all' | 'collection' | 'expense'

  @override
  Widget build(BuildContext context) {
    final fund = context.watch<CommunityFundProvider>();
    final theme = RoleTheme.of(UserRole.president);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final all = fund.transactions;
    final filtered = _filter == 'all'
        ? all
        : all.where((t) => t.type == _filter).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('All Transactions',
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
      ),
      body: Column(
        children: [
          // Filter chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                _Chip(label: 'All', selected: _filter == 'all',
                    onTap: () => setState(() => _filter = 'all'),
                    color: theme.effectivePrimary(context)),
                const SizedBox(width: 8),
                _Chip(label: 'Collections', selected: _filter == FundTxnType.collection,
                    onTap: () => setState(() => _filter = FundTxnType.collection),
                    color: AppColors.paid),
                const SizedBox(width: 8),
                _Chip(label: 'Expenses', selected: _filter == FundTxnType.expense,
                    onTap: () => setState(() => _filter = FundTxnType.expense),
                    color: AppColors.overdue),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: fund.isLoading && all.isEmpty
                ? const ShimmerDashboard()
                : filtered.isEmpty
                    ? const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No Transactions',
                        subtitle: 'No entries match the selected filter.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _TxnCard(
                          txn: filtered[i],
                          aptId: widget.aptId,
                          cs: cs,
                          isDark: isDark,
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: selected ? 1 : 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}

class _TxnCard extends StatelessWidget {
  final FundTransaction txn;
  final String aptId;
  final ColorScheme cs;
  final bool isDark;
  const _TxnCard({
    required this.txn,
    required this.aptId,
    required this.cs,
    required this.isDark,
  });

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await AppUtils.showConfirmDialog(
      context,
      title: 'Delete Transaction',
      message: 'This will reverse the balance effect. Are you sure?',
      confirmText: 'Delete',
      confirmColor: AppColors.overdue,
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await context.read<CommunityFundProvider>().deleteTransaction(
            txnId: txn.id,
            aptId: aptId,
            amountPaise: txn.amountPaise,
            type: txn.type,
          );
      if (context.mounted) {
        AppUtils.showSnackBar(context, 'Transaction deleted.',
            color: AppColors.paid);
      }
    } catch (e) {
      if (context.mounted) AppUtils.showSnackBar(context, 'Failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = txn.isCollection;
    final color = isIncome ? AppColors.paid : AppColors.overdue;
    final sign = isIncome ? '+' : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                    style: AppTextStyles.bodyMedium(color: cs.onSurface)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  children: [
                    if (!isIncome)
                      _Label(txn.category, cs: cs),
                    if (txn.receiptNote != null) ...[
                      _Label(txn.receiptNote!, cs: cs),
                    ],
                    _Label(AppUtils.formatDate(txn.createdAt), cs: cs),
                  ],
                ),
                const SizedBox(height: 2),
                Text('by ${txn.createdByName}',
                    style: AppTextStyles.caption(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$sign${AppUtils.formatCurrency(txn.amount)}',
                style: AppTextStyles.subheading(color: color)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _confirmDelete(context),
                child: Icon(Icons.delete_outline_rounded,
                    color: cs.onSurfaceVariant, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final ColorScheme cs;
  const _Label(this.text, {required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          style: AppTextStyles.caption(color: cs.onSurfaceVariant)
              .copyWith(fontSize: 10)),
    );
  }
}
