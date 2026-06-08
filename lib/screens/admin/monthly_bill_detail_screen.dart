import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/bill_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../models/user_model.dart';

class MonthlyBillDetailScreen extends StatelessWidget {
  final MonthlyBillSummary summary;
  final String aptId;

  const MonthlyBillDetailScreen({
    super.key,
    required this.summary,
    required this.aptId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = RoleTheme.of(UserRole.admin);
    final billProvider = context.watch<BillProvider>();

    // Re-fetch fresh summary so UI updates after markPaid
    final fresh = billProvider.monthlyBillsForApartment(aptId).firstWhere(
          (s) => s.month == summary.month,
          orElse: () => summary,
        );

    final flats = fresh.flatList;

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
      body: CustomScrollView(
        slivers: [
          // Summary header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                children: [
                  // Bill categories breakdown
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
                        Text('Bill Breakdown',
                            style: AppTextStyles.subheading()),
                        const SizedBox(height: 12),
                        ...fresh.bills.map((bill) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color:
                                          theme.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                        _categoryIcon(bill.category),
                                        color: theme.primary,
                                        size: 16),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(bill.title,
                                        style: AppTextStyles.bodyMedium(
                                            color:
                                                AppColors.textPrimary)),
                                  ),
                                  Text(
                                    AppUtils.formatCurrency(
                                        bill.perFlatShare),
                                    style: AppTextStyles.bodyMedium(
                                            color: theme.primary)
                                        .copyWith(
                                            fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            )),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total per flat',
                                style: AppTextStyles.subheading()),
                            Text(
                              AppUtils.formatCurrency(fresh.perFlatShare),
                              style: AppTextStyles.subheading(
                                  color: theme.primary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Payment progress summary
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
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Collection Progress',
                                style: AppTextStyles.subheading()),
                            Text(
                              '${fresh.fullyPaidFlats}/${fresh.totalFlats} flats',
                              style: AppTextStyles.subheading(
                                  color: theme.primary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: fresh.totalFlats == 0
                                ? 0
                                : fresh.fullyPaidFlats / fresh.totalFlats,
                            backgroundColor: AppColors.lightGray,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                fresh.fullyPaidFlats == fresh.totalFlats &&
                                        fresh.totalFlats > 0
                                    ? AppColors.green
                                    : theme.primary),
                            minHeight: 10,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Due: ${AppUtils.formatDate(fresh.dueDate)}',
                              style: AppTextStyles.caption(),
                            ),
                            Text(
                              'Collected: ${AppUtils.formatCurrency(fresh.fullyPaidFlats * fresh.perFlatShare)}',
                              style: AppTextStyles.caption(
                                  color: AppColors.green),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Flat-wise Status',
                        style: AppTextStyles.heading3()),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),

          // Per-flat list
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final flat = flats[i];
                final isPaid = fresh.isUserFullyPaid(flat.userId);
                final paidDate = fresh.userPaidDate(flat.userId);
                final userName = MockUsers.findById(flat.userId)?.name;

                return Padding(
                  padding: EdgeInsets.fromLTRB(
                      16, 0, 16, i == flats.length - 1 ? 100 : 10),
                  child: _FlatPaymentCard(
                    unitNumber: flat.unitNumber,
                    userName: userName,
                    isPaid: isPaid,
                    paidDate: paidDate,
                    isLoading: billProvider.isLoading,
                    onMarkPaid: isPaid
                        ? null
                        : () async {
                            await context
                                .read<BillProvider>()
                                .adminMarkMonthPaid(
                                    summary.month, aptId, flat.userId);
                            if (!ctx.mounted) return;
                            AppUtils.showSnackBar(ctx,
                                '${flat.unitNumber} marked as paid!',
                                color: AppColors.green);
                          },
                  ),
                );
              },
              childCount: flats.length,
            ),
          ),
        ],
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
}

class _FlatPaymentCard extends StatelessWidget {
  final String unitNumber;
  final String? userName;
  final bool isPaid;
  final DateTime? paidDate;
  final bool isLoading;
  final VoidCallback? onMarkPaid;

  const _FlatPaymentCard({
    required this.unitNumber,
    this.userName,
    required this.isPaid,
    this.paidDate,
    required this.isLoading,
    this.onMarkPaid,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: isPaid
            ? Border.all(color: AppColors.green.withOpacity(0.3))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Unit badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              unitNumber,
              style: AppTextStyles.label(color: AppColors.blue)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (userName != null)
                  Text(userName!,
                      style: AppTextStyles.bodyMedium(
                          color: AppColors.textPrimary)
                          .copyWith(fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                if (isPaid && paidDate != null)
                  Text(
                    'Paid on ${AppUtils.formatDateTime(paidDate!)}',
                    style:
                        AppTextStyles.caption(color: AppColors.green),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Text('Payment pending',
                      style: AppTextStyles.caption(
                          color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isPaid)
            const Icon(Icons.check_circle_rounded,
                color: AppColors.green, size: 24)
          else
            GestureDetector(
              onTap: isLoading ? null : onMarkPaid,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.green, AppColors.teal],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Mark Paid',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
