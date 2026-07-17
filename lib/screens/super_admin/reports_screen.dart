import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../providers/bill_provider.dart';
import '../../providers/apartment_provider.dart';
import '../../providers/user_provider.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final billProvider = context.watch<BillProvider>();
    final aptProvider = context.watch<ApartmentProvider>();
    final userProvider = context.watch<UserProvider>();

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = RoleTheme.of(UserRole.superAdmin).effectivePrimary(context);

    // Global totals from all apartments
    double totalCollected = 0;
    double totalPending = 0;
    for (final apt in aptProvider.apartments) {
      totalCollected += billProvider.collectedForApartment(apt.id);
      totalPending += billProvider.pendingForApartment(apt.id);
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
                  color: accent.withOpacity(0.25),
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
          Text('Per Apartment', style: AppTextStyles.heading3(color: cs.onSurface)),
          const SizedBox(height: 14),

          ...aptProvider.apartments.map((apt) {
            final bills = billProvider.billsForApartment(apt.id);
            final collected = billProvider.collectedForApartment(apt.id);
            final pending = billProvider.pendingForApartment(apt.id);
            int paidPayments = 0;
            int totalPayments = 0;
            for (final bill in bills) {
              for (final p in billProvider.paymentsForBill(bill.id)) {
                totalPayments++;
                if (p.isPaid) paidPayments++;
              }
            }
            final rate =
                totalPayments == 0 ? 0.0 : paidPayments / totalPayments;

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
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
                          color: accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.apartment_outlined,
                            color: accent, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(apt.name,
                            style: AppTextStyles.subheading(color: cs.onSurface)),
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
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: rate,
                      backgroundColor: cs.outlineVariant,
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
          Text('Resident Activity', style: AppTextStyles.heading3(color: cs.onSurface)),
          const SizedBox(height: 14),

          ...userProvider.residents.map((user) {
            final payments = billProvider.paymentsForUser(user.id);
            final paid = payments.where((p) => p.isPaid).length;
            final total = payments.length;
            double totalPaidAmt = 0;
            for (final p in payments.where((p) => p.isPaid)) {
              final aptBills = billProvider.billsForApartment(user.apartmentId ?? '');
              try {
                final bill = aptBills.firstWhere((b) => b.id == p.billId);
                totalPaidAmt += bill.perFlatShare;
              } catch (_) {}
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
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
                        Text(user.name, style: AppTextStyles.label(color: cs.onSurface)),
                        Text(user.unit, style: AppTextStyles.caption(color: cs.onSurfaceVariant)),
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
