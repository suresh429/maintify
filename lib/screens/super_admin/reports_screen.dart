import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_utils.dart';
import '../../models/apartment_model.dart';
import '../../models/user_model.dart';
import '../../models/bill_model.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Global totals from payment records
    double totalCollected = 0;
    double totalPending = 0;
    for (final bill in MockBillData.bills) {
      for (final p in MockBillData.paymentsForBill(bill.id)) {
        if (p.isPaid) {
          totalCollected += bill.perFlatShare;
        } else {
          totalPending += bill.perFlatShare;
        }
      }
    }
    final collectionRate = (totalCollected + totalPending) == 0
        ? 0.0
        : totalCollected / (totalCollected + totalPending) * 100;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall summary
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppColors.superAdminGradient,
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.purple.withOpacity(0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.analytics_outlined,
                        color: Colors.white, size: 24),
                    const SizedBox(width: 10),
                    Text('Platform Report',
                        style:
                            AppTextStyles.subheading(color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _ReportStat(
                        label: 'Total Collected',
                        value: AppUtils.formatCurrency(totalCollected),
                        light: true,
                      ),
                    ),
                    Expanded(
                      child: _ReportStat(
                        label: 'Total Pending',
                        value: AppUtils.formatCurrency(totalPending),
                        light: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Collection Rate',
                        style: AppTextStyles.bodySmall(
                            color: Colors.white.withOpacity(0.8))),
                    Text(
                      '${collectionRate.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: collectionRate / 100,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Text('Per Apartment', style: AppTextStyles.heading3()),
          const SizedBox(height: 14),

          ...MockApartments.all.map((apt) {
            final bills = MockBillData.billsForApartment(apt.id);
            double collected = 0;
            double pending = 0;
            int paidPayments = 0;
            int totalPayments = 0;

            for (final bill in bills) {
              for (final p in MockBillData.paymentsForBill(bill.id)) {
                totalPayments++;
                if (p.isPaid) {
                  paidPayments++;
                  collected += bill.perFlatShare;
                } else {
                  pending += bill.perFlatShare;
                }
              }
            }
            final rate =
                totalPayments == 0 ? 0.0 : paidPayments / totalPayments;

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
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
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.apartment_outlined,
                            color: AppColors.purple, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(apt.name,
                            style: AppTextStyles.subheading()),
                      ),
                      Text(
                        '${(rate * 100).toInt()}%',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.bold,
                          color: rate > 0.7
                              ? AppColors.green
                              : AppColors.pending,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ReportStat(
                          label: 'Collected',
                          value: AppUtils.formatCurrency(collected),
                          color: AppColors.green,
                        ),
                      ),
                      Expanded(
                        child: _ReportStat(
                          label: 'Pending',
                          value: AppUtils.formatCurrency(pending),
                          color: AppColors.pending,
                        ),
                      ),
                      Expanded(
                        child: _ReportStat(
                          label: 'Bills',
                          value: '${bills.length}',
                          color: AppColors.purple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: rate,
                      backgroundColor: AppColors.lightGray,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          rate > 0.7 ? AppColors.green : AppColors.pending),
                      minHeight: 5,
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 24),
          Text('Resident Activity', style: AppTextStyles.heading3()),
          const SizedBox(height: 14),

          ...MockUsers.residents.map((user) {
            final payments = MockBillData.paymentsForUser(user.id);
            final paid = payments.where((p) => p.isPaid).length;
            final total = payments.length;
            final totalPaidAmt = payments
                .where((p) => p.isPaid)
                .fold(0.0, (s, p) {
              final bill = MockBillData.bills.firstWhere(
                  (b) => b.id == p.billId,
                  orElse: () => MockBillData.bills.first);
              return s + bill.perFlatShare;
            });

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
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
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(user.avatarInitials,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.bold,
                            color: AppColors.green,
                            fontSize: 14,
                          )),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name, style: AppTextStyles.label()),
                        Text(user.unit, style: AppTextStyles.caption()),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$paid/$total paid',
                          style: AppTextStyles.label(
                              color: paid == total
                                  ? AppColors.green
                                  : AppColors.pending)),
                      if (total > 0)
                        Text(
                          AppUtils.formatCurrency(totalPaidAmt),
                          style:
                              AppTextStyles.caption(color: AppColors.green),
                        ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _ReportStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool light;
  const _ReportStat({
    required this.label,
    required this.value,
    this.color,
    this.light = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: light ? Colors.white : (color ?? AppColors.textPrimary),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            color: light
                ? Colors.white.withOpacity(0.75)
                : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
