import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bill_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../widgets/shimmer_loading.dart';

class PaymentHistoryScreen extends StatelessWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final userId = auth.currentUser?.id ?? '';
    final billProvider = context.watch<BillProvider>();
    final theme = RoleTheme.of(UserRole.user);

    final allViews = billProvider.userBillViews(userId);
    final paidViews = allViews.where((v) => v.payment.isPaid).toList()
      ..sort((a, b) => (b.payment.paidDate ?? b.bill.dueDate)
          .compareTo(a.payment.paidDate ?? a.bill.dueDate));

    final totalPaid = billProvider.totalPaidForUser(userId);

    // Column + Expanded is the correct pattern for a bounded tab body.
    // SingleChildScrollView at root causes empty space because IndexedStack
    // gives the child the full screen height regardless of content length.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Summary card ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: _SummaryCard(
            totalPaid: totalPaid,
            count: paidViews.length,
            theme: theme,
          ),
        ),

        const SizedBox(height: 20),

        // ── Section header ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Transactions', style: AppTextStyles.heading3(color: Theme.of(context).colorScheme.onSurface)),
              Builder(builder: (ctx) {
                final accent = theme.effectivePrimary(ctx);
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${paidViews.length} total',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── Transaction list — Expanded fills remaining screen ─────────────
        Expanded(
          child: paidViews.isEmpty
              ? const EmptyState(
                  title: 'No Payments Yet',
                  subtitle:
                      'Bills you pay will appear here as transactions',
                  icon: Icons.receipt_long_outlined,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: paidViews.length,
                  itemBuilder: (_, i) {
                    final showMonth = i == 0 ||
                        paidViews[i].bill.month !=
                            paidViews[i - 1].bill.month;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showMonth) _MonthDivider(paidViews[i].bill.month),
                        _PaymentCard(view: paidViews[i]),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ── Summary Card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final double totalPaid;
  final int count;
  final RoleTheme theme;

  const _SummaryCard({
    required this.totalPaid,
    required this.count,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            color: theme.primary.withOpacity(0.28),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Paid',
                  style: AppTextStyles.caption(
                      color: Colors.white.withOpacity(0.8)),
                ),
                const SizedBox(height: 6),
                Text(
                  AppUtils.formatCurrency(totalPaid),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 30,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            '$count payment${count != 1 ? 's' : ''} completed',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.account_balance_wallet_outlined,
                color: Colors.white, size: 30),
          ),
        ],
      ),
    );
  }
}

// ── Month divider ─────────────────────────────────────────────────────────────

class _MonthDivider extends StatelessWidget {
  final String month;
  const _MonthDivider(this.month);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Builder(builder: (ctx) => Text(
        month.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Theme.of(ctx).colorScheme.onSurfaceVariant,
          letterSpacing: 1.2,
        ),
      )),
    );
  }
}

// ── Payment Card ──────────────────────────────────────────────────────────────

class _PaymentCard extends StatelessWidget {
  final UserBillView view;
  const _PaymentCard({required this.view});

  IconData get _categoryIcon {
    switch (view.bill.category) {
      case 'Maintenance':
        return Icons.build_outlined;
      case 'Utilities':
        return Icons.bolt_outlined;
      case 'Parking':
        return Icons.local_parking_outlined;
      case 'Amenities':
        return Icons.fitness_center_outlined;
      case 'Security':
        return Icons.security_outlined;
      default:
        return Icons.receipt_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bill = view.bill;
    final payment = view.payment;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Top row: icon + title + amount ────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.paid.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_categoryIcon,
                      color: AppColors.paid, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bill.title,
                        style: AppTextStyles.subheading(color: cs.onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        bill.category,
                        style: AppTextStyles.caption(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      AppUtils.formatCurrency(bill.perFlatShare),
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.paid.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Paid',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.paid,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Divider ───────────────────────────────────────────────────
          Divider(height: 1, indent: 16, endIndent: 16, color: cs.outlineVariant),

          // ── Bottom row: meta info ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Row(
              children: [
                // Paid date
                _MetaChip(
                  icon: Icons.calendar_today_outlined,
                  label: payment.paidDate != null
                      ? AppUtils.formatDate(payment.paidDate!)
                      : '—',
                ),
                const SizedBox(width: 8),
                // Split info
                _MetaChip(
                  icon: Icons.people_outline,
                  label:
                      '${AppUtils.formatCurrency(bill.totalAmount)} ÷ ${bill.totalFlats}',
                ),
                if (payment.transactionId != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetaChip(
                      icon: Icons.tag_rounded,
                      label: payment.transactionId!,
                      color: AppColors.paid,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _MetaChip(
      {required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: c),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: c,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
