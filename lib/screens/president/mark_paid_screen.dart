import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/bill_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bill_provider.dart';
import '../../providers/user_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../widgets/shimmer_loading.dart';
import 'monthly_bill_detail_screen.dart';

class MarkPaidScreen extends StatelessWidget {
  const MarkPaidScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final aptId = auth.currentUser?.apartmentId ?? '';
    final billProvider = context.watch<BillProvider>();
    final theme = RoleTheme.of(UserRole.president);

    if (billProvider.isLoading) return const ShimmerDashboard();

    final monthlySummaries = billProvider.monthlyBillsForApartment(aptId);
    final pendingApprovals =
        billProvider.pendingApprovalPaymentsForApartment(aptId);
    final presidentId = auth.currentUser?.id ?? '';

    if (monthlySummaries.isEmpty) {
      return const EmptyState(
        title: 'No Bills Yet',
        subtitle: 'Create a monthly bill to get started',
        icon: Icons.receipt_long_outlined,
      );
    }

    return CustomScrollView(
      slivers: [
        // ── Pending Approvals section ─────────────────────────────────────
        if (pendingApprovals.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_top_rounded,
                      size: 17, color: Color(0xFFD97706)),
                  const SizedBox(width: 6),
                  Text(
                    'Pending Approvals (${pendingApprovals.length})',
                    style: AppTextStyles.label(color: const Color(0xFFD97706))
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final payment = pendingApprovals[i];
                final userName =
                    ctx.read<UserProvider>().findById(payment.userId)?.name;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: _PendingApprovalCard(
                    payment: payment,
                    userName: userName,
                    theme: theme,
                    presidentId: presidentId,
                    aptId: aptId,
                    isLoading: billProvider.isLoading,
                  ),
                );
              },
              childCount: pendingApprovals.length,
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Divider(),
            ),
          ),
        ],

        // ── Monthly summaries ─────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text('Monthly Bills',
                style: AppTextStyles.heading3()),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 0, 16, i == monthlySummaries.length - 1 ? 100 : 0),
              child: _MonthlyCard(
                summary: monthlySummaries[i],
                theme: theme,
                aptId: aptId,
              ),
            ),
            childCount: monthlySummaries.length,
          ),
        ),
      ],
    );
  }
}

class _MonthlyCard extends StatelessWidget {
  final MonthlyBillSummary summary;
  final RoleTheme theme;
  final String aptId;

  const _MonthlyCard({
    required this.summary,
    required this.theme,
    required this.aptId,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = theme.effectivePrimary(context);
    final paidCount = summary.fullyPaidFlats;
    final total = summary.totalFlats;
    final progress = total == 0 ? 0.0 : paidCount / total;

    Color statusColor;
    String statusLabel;
    switch (summary.overallStatus) {
      case 'Paid':
        statusColor = AppColors.green;
        statusLabel = 'Fully Paid';
        break;
      case 'Partial':
        statusColor = AppColors.pending;
        statusLabel = 'Partial';
        break;
      default:
        statusColor = AppColors.overdue;
        statusLabel = 'Pending';
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MonthlyBillDetailScreen(
            summary: summary,
            aptId: aptId,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
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
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accent.withValues(alpha: 0.07),
                    accent.withValues(alpha: 0.01),
                  ],
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.calendar_month_rounded,
                        color: accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(summary.month,
                            style: AppTextStyles.subheading(color: cs.onSurface)),
                        const SizedBox(height: 2),
                        Text(
                          '${summary.bills.length} categor${summary.bills.length == 1 ? 'y' : 'ies'} · ${AppUtils.formatCurrency(summary.totalAmount)} total',
                          style: AppTextStyles.caption(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${AppUtils.formatCurrency(summary.perFlatShare)}/flat',
                        style: AppTextStyles.caption(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Progress section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$paidCount of $total flats paid',
                        style: AppTextStyles.caption(color: cs.onSurfaceVariant),
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: AppTextStyles.caption(color: accent)
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: cs.outlineVariant,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          paidCount == total && total > 0
                              ? AppColors.green
                              : accent),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _StatPill(
                        label: 'Collected',
                        value: AppUtils.formatCurrency(
                            paidCount * summary.perFlatShare),
                        color: AppColors.green,
                      ),
                      _StatPill(
                        label: 'Pending',
                        value: AppUtils.formatCurrency(
                            (total - paidCount) * summary.perFlatShare),
                        color: AppColors.overdue,
                      ),
                      Row(
                        children: [
                          Text('View Details',
                              style: AppTextStyles.caption(
                                  color: accent)),
                          const SizedBox(width: 2),
                          Icon(Icons.chevron_right_rounded,
                              color: accent, size: 16),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatPill(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption(color: cs.onSurfaceVariant)),
        Text(value,
            style: AppTextStyles.caption(color: color)
                .copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ── Pending Approval Card ─────────────────────────────────────────────────────

class _PendingApprovalCard extends StatelessWidget {
  final BillPayment payment;
  final String? userName;
  final RoleTheme theme;
  final String presidentId;
  final String aptId;
  final bool isLoading;

  const _PendingApprovalCard({
    required this.payment,
    this.userName,
    required this.theme,
    required this.presidentId,
    required this.aptId,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    payment.unitNumber,
                    style: AppTextStyles.label(
                            color: const Color(0xFFD97706))
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (userName != null)
                        Text(
                          userName!,
                          style:
                              AppTextStyles.bodyMedium(color: cs.onSurface)
                                  .copyWith(fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      Text(
                        payment.submittedAt != null
                            ? 'Submitted ${AppUtils.formatDateTime(payment.submittedAt!)}'
                            : 'Awaiting your approval',
                        style: AppTextStyles.caption(
                            color: const Color(0xFFD97706)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (payment.amount != null)
                  Text(
                    AppUtils.formatCurrency(payment.amount!),
                    style: AppTextStyles.subheading(
                            color: cs.onSurface)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
              ],
            ),
          ),

          // Approve / Reject strip
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.06),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(14)),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isLoading
                        ? null
                        : () async {
                            // Find the month for this payment
                            final bp = context.read<BillProvider>();
                            final month = bp.monthForBill(payment.billId);
                            if (month == null) return;
                            await bp.presidentRejectPaymentForFlat(
                              month: month,
                              aptId: aptId,
                              userId: payment.userId,
                              presidentId: presidentId,
                              unitNumber: payment.unitNumber,
                            );
                            if (!context.mounted) return;
                            AppUtils.showSnackBar(
                                context, 'Payment rejected.',
                                isError: true);
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.overdue,
                      side: BorderSide(
                          color: AppColors.overdue.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: Text('Reject',
                        style:
                            AppTextStyles.caption(color: AppColors.overdue)
                                .copyWith(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isLoading
                        ? null
                        : () async {
                            final bp = context.read<BillProvider>();
                            final month = bp.monthForBill(payment.billId);
                            if (month == null) return;
                            await bp.presidentApprovePaymentForFlat(
                              month: month,
                              aptId: aptId,
                              userId: payment.userId,
                              presidentId: presidentId,
                              unitNumber: payment.unitNumber,
                            );
                            if (!context.mounted) return;
                            AppUtils.showSnackBar(
                                context, 'Payment approved!',
                                color: AppColors.paid);
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.paid,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.check_rounded,
                        size: 16, color: Colors.white),
                    label: Text('Approve',
                        style:
                            AppTextStyles.caption(color: Colors.white)
                                .copyWith(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
