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

    // Re-fetch fresh summary so UI updates after payment
    final allSummaries = billProvider.userMonthlySummaries(userId);
    final fresh = allSummaries.firstWhere(
      (s) => s.month == summary.month,
      orElse: () => summary,
    );

    Color statusColor;
    String statusLabel;
    switch (fresh.status) {
      case 'Paid':
        statusColor = AppColors.paid;
        statusLabel = 'Paid';
        break;
      case 'Partial':
        statusColor = AppColors.pending;
        statusLabel = 'Partially Paid';
        break;
      case 'Overdue':
        statusColor = AppColors.overdue;
        statusLabel = 'Overdue';
        break;
      default:
        statusColor = AppColors.overdue;
        statusLabel = 'Pending';
    }

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
            // Bill breakdown card
            Container(
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
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.primary.withOpacity(0.08),
                          theme.primary.withOpacity(0.01),
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Bill Details',
                                  style: AppTextStyles.subheading()),
                              Text(summary.month,
                                  style: AppTextStyles.caption()),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Line items
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        ...fresh.views.map((v) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _categoryColor(v.bill.category)
                                          .withOpacity(0.1),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      _categoryIcon(v.bill.category),
                                      color:
                                          _categoryColor(v.bill.category),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(v.bill.title,
                                            style:
                                                AppTextStyles.bodyMedium(
                                                    color: AppColors
                                                        .textPrimary)
                                                    .copyWith(
                                                        fontWeight:
                                                            FontWeight.w500)),
                                        Text(v.bill.category,
                                            style:
                                                AppTextStyles.caption()),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        AppUtils.formatCurrency(
                                            v.bill.perFlatShare),
                                        style: AppTextStyles.bodyMedium(
                                                color: AppColors.textPrimary)
                                            .copyWith(
                                                fontWeight: FontWeight.w600),
                                      ),
                                      if (v.payment.isPaid)
                                        const Icon(
                                            Icons.check_circle_outline,
                                            color: AppColors.paid,
                                            size: 14)
                                      else
                                        const Icon(
                                            Icons.radio_button_unchecked,
                                            color: AppColors.textSecondary,
                                            size: 14),
                                    ],
                                  ),
                                ],
                              ),
                            )),

                        const Divider(height: 8),
                        const SizedBox(height: 8),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Amount',
                                style: AppTextStyles.subheading()),
                            Text(
                              AppUtils.formatCurrency(fresh.totalAmount),
                              style: AppTextStyles.subheading(
                                  color: theme.primary),
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
            ),

            const SizedBox(height: 16),

            // Payment status card
            Container(
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
                  Text('Payment Info', style: AppTextStyles.subheading()),
                  const SizedBox(height: 14),

                  if (fresh.isFullyPaid) ...[
                    // Paid state
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.paid.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.paid.withOpacity(0.3)),
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
                                    style: AppTextStyles.caption(
                                        color: AppColors.paid),
                                  ),
                                if (fresh.views.isNotEmpty &&
                                    fresh.views.last.payment.transactionId !=
                                        null)
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
                    // Pending state — show Pay Now
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.pending.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.pending.withOpacity(0.3)),
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
                                        .copyWith(
                                            fontWeight: FontWeight.w600)),
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
                        text: 'Pay Now  ${AppUtils.formatCurrency(fresh.totalAmount)}',
                        gradient: theme.gradient,
                        icon: Icons.payment_rounded,
                        isLoading: bp.isLoading,
                        onPressed: () async {
                          await bp.userPayMonthlyBill(
                              summary.month, aptId, userId);
                          if (!context.mounted) return;
                          AppUtils.showSnackBar(context,
                              'Payment successful!',
                              color: AppColors.paid);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Water':
        return Icons.water_drop_outlined;
      case 'Lift':
        return Icons.elevator_outlined;
      case 'Security':
        return Icons.security_outlined;
      case 'Maintenance':
        return Icons.build_outlined;
      case 'Parking':
        return Icons.local_parking_outlined;
      case 'Amenities':
        return Icons.fitness_center_outlined;
      default:
        return Icons.receipt_outlined;
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Water':
        return AppColors.teal;
      case 'Lift':
        return AppColors.purple;
      case 'Security':
        return AppColors.pending;
      case 'Maintenance':
        return AppColors.blue;
      case 'Parking':
        return AppColors.textSecondary;
      case 'Amenities':
        return AppColors.paid;
      default:
        return AppColors.textSecondary;
    }
  }
}
