import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bill_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../widgets/common_button.dart';

class UserMonthlyBillDetailScreen extends StatelessWidget {
  final UserMonthlySummary summary;
  final String aptId;

  const UserMonthlyBillDetailScreen({
    super.key,
    required this.summary,
    required this.aptId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = RoleTheme.of(UserRole.user);
    final billProvider = context.watch<BillProvider>();
    final auth = context.read<AuthProvider>();
    final userId = auth.currentUser?.id ?? '';

    final allSummaries = billProvider.userMonthlySummaries(userId);
    final fresh = allSummaries.firstWhere(
      (s) => s.month == summary.month,
      orElse: () => summary,
    );

    // Apartment-level total = sum of each bill's totalAmount
    final aptTotal =
        fresh.views.fold<double>(0, (s, v) => s + v.bill.totalAmount);

    final statusColor = _statusColor(fresh.status);
    final statusLabel = _statusLabel(fresh.status);

    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(summary.month,
            style: AppTextStyles.heading3(color: Colors.white)),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: theme.gradient,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section 1: Hero Card ───────────────────────────────────────
            _buildHeroCard(theme, fresh, aptTotal, statusLabel),
            const SizedBox(height: 14),

            // ── Section 2: Category Breakdown ─────────────────────────────
            _buildCategoryBreakdown(theme, fresh, aptTotal, statusColor),
            const SizedBox(height: 14),

            // ── Section 3: Payment Info ────────────────────────────────────
            _buildPaymentInfo(context, theme, fresh, userId, billProvider),
          ],
        ),
      ),
    );
  }

  // ── Hero Card ───────────────────────────────────────────────────────────────

  Widget _buildHeroCard(
    RoleTheme theme,
    UserMonthlySummary fresh,
    double aptTotal,
    String statusLabel,
  ) {
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
            color: theme.primary.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month + status chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                fresh.month,
                style: AppTextStyles.caption(
                    color: Colors.white.withOpacity(0.8)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.3), width: 1),
                ),
                child: Text(
                  statusLabel,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // My share (big) + wallet icon
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Share',
                      style: AppTextStyles.bodySmall(
                          color: Colors.white.withOpacity(0.8)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppUtils.formatCurrency(fresh.totalAmount),
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Colors.white,
                    size: 28),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Context stats
          Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                _heroStat(
                  Icons.apartment_outlined,
                  AppUtils.formatCurrency(aptTotal),
                  'Apt. Total',
                ),
                _divider(),
                _heroStat(
                  Icons.calendar_today_outlined,
                  _shortDate(fresh.dueDate),
                  'Due Date',
                ),
                _divider(),
                _heroStat(
                  Icons.receipt_long_outlined,
                  '${fresh.views.length}',
                  'Bills',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroStat(IconData icon, String value, String label) => Expanded(
        child: Column(
          children: [
            Icon(icon, color: Colors.white70, size: 14),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 9,
                color: Colors.white.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  Widget _divider() =>
      Container(width: 1, height: 28, color: Colors.white.withOpacity(0.2));

  // ── Category Breakdown Card ─────────────────────────────────────────────────

  Widget _buildCategoryBreakdown(
    RoleTheme theme,
    UserMonthlySummary fresh,
    double aptTotal,
    Color statusColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
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
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.bar_chart_rounded,
                    size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                    child:
                        Text('Category Breakdown', style: AppTextStyles.subheading())),
                // Column labels
                Text('Apt. Total',
                    style: AppTextStyles.caption(
                        color: AppColors.textSecondary)),
                const SizedBox(width: 12),
                SizedBox(
                  width: 60,
                  child: Text('My Share',
                      style: AppTextStyles.caption(color: theme.primary),
                      textAlign: TextAlign.right),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
          const Divider(height: 1),

          // Per-bill rows
          ...fresh.views.map((v) {
            final isPaid = v.payment.isPaid;
            final catColor = _categoryColor(v.bill.category);
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: catColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_categoryIcon(v.bill.category),
                            color: catColor, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(v.bill.title,
                                style: AppTextStyles.bodyMedium(
                                        color: AppColors.textPrimary)
                                    .copyWith(fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text(v.bill.category,
                                style: AppTextStyles.caption()),
                          ],
                        ),
                      ),
                      // Apt. total
                      Text(
                        AppUtils.formatCurrency(v.bill.totalAmount),
                        style: AppTextStyles.caption(
                                color: AppColors.textSecondary)
                            .copyWith(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 12),
                      // My share + status icon (uses per-user amount for individual bills)
                      SizedBox(
                        width: 60,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              AppUtils.formatCurrency(v.userAmount),
                              style: AppTextStyles.bodySmall(
                                      color: AppColors.textPrimary)
                                  .copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              isPaid
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked,
                              size: 14,
                              color: isPaid
                                  ? AppColors.paid
                                  : AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (v != fresh.views.last) const Divider(height: 1),
              ],
            );
          }),

          const Divider(height: 1),

          // Totals footer
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Apartment Total',
                        style: AppTextStyles.bodyMedium(
                            color: AppColors.textPrimary)),
                    Text(
                      AppUtils.formatCurrency(aptTotal),
                      style: AppTextStyles.bodyMedium(
                              color: AppColors.textSecondary)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Your Total Share',
                        style: AppTextStyles.subheading()),
                    Text(
                      AppUtils.formatCurrency(fresh.totalAmount),
                      style: AppTextStyles.subheading(color: theme.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Due Date', style: AppTextStyles.caption()),
                    Text(AppUtils.formatDate(fresh.dueDate),
                        style: AppTextStyles.caption()),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Payment Info Card ───────────────────────────────────────────────────────

  Widget _buildPaymentInfo(
    BuildContext context,
    RoleTheme theme,
    UserMonthlySummary fresh,
    String userId,
    BillProvider billProvider,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
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
            children: [
              const Icon(Icons.payments_outlined,
                  size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text('Payment Info', style: AppTextStyles.subheading()),
            ],
          ),
          const SizedBox(height: 14),

          if (fresh.isFullyPaid) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.paid.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.paid.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.paid, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Payment Received',
                            style: AppTextStyles.subheading(
                                color: AppColors.paid)),
                        if (fresh.paidDate != null)
                          Text(
                            'Paid on ${AppUtils.formatDateTime(fresh.paidDate!)}',
                            style:
                                AppTextStyles.caption(color: AppColors.paid),
                          ),
                        if (fresh.views.isNotEmpty &&
                            fresh.views.last.payment.transactionId != null)
                          Text(
                            'Txn: ${fresh.views.last.payment.transactionId}',
                            style: AppTextStyles.caption(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.pending.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.pending.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded,
                      color: AppColors.pending, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Payment Pending',
                            style: AppTextStyles.bodyMedium(
                                    color: AppColors.textPrimary)
                                .copyWith(fontWeight: FontWeight.w600)),
                        Text(
                          'Due: ${AppUtils.formatDate(fresh.dueDate)}',
                          style: AppTextStyles.caption(
                              color: AppColors.pending),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Consumer<BillProvider>(
              builder: (_, bp, __) => CommonButton(
                text:
                    'Mark as Paid  ${AppUtils.formatCurrency(fresh.totalAmount)}',
                gradient: theme.gradient,
                icon: Icons.check_circle_outline_rounded,
                isLoading: bp.isLoading,
                onPressed: () async {
                  await bp.userPayMonthlyBill(
                      summary.month, aptId, userId);
                  if (!context.mounted) return;
                  AppUtils.showSnackBar(context, 'Marked as paid!',
                      color: AppColors.paid);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String _shortDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Paid':    return AppColors.paid;
      case 'Partial': return AppColors.pending;
      case 'Overdue': return AppColors.overdue;
      default:        return AppColors.overdue;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'Paid':    return 'Paid';
      case 'Partial': return 'Partially Paid';
      case 'Overdue': return 'Overdue';
      default:        return 'Pending';
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Water':      return Icons.water_drop_outlined;
      case 'Lift':       return Icons.elevator_outlined;
      case 'Security':   return Icons.security_outlined;
      case 'Maintenance':return Icons.build_outlined;
      case 'Parking':    return Icons.local_parking_outlined;
      case 'Amenities':  return Icons.fitness_center_outlined;
      default:           return Icons.receipt_outlined;
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Water':      return AppColors.teal;
      case 'Lift':       return AppColors.purple;
      case 'Security':   return AppColors.overdue;
      case 'Maintenance':return AppColors.blue;
      case 'Parking':    return AppColors.textSecondary;
      case 'Amenities':  return AppColors.paid;
      default:           return AppColors.textSecondary;
    }
  }
}
