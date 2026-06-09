import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bill_provider.dart';
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
    final theme = RoleTheme.of(UserRole.admin);

    if (billProvider.isLoading) return const ShimmerDashboard();

    final monthlySummaries = billProvider.monthlyBillsForApartment(aptId);

    return monthlySummaries.isEmpty
        ? const EmptyState(
            title: 'No Bills Yet',
            subtitle: 'Create a monthly bill to get started',
            icon: Icons.receipt_long_outlined,
          )
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: monthlySummaries.length,
            itemBuilder: (_, i) => _MonthlyCard(
              summary: monthlySummaries[i],
              theme: theme,
              aptId: aptId,
            ),
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
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.primary.withOpacity(0.07),
                    theme.primary.withOpacity(0.01),
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
                      color: theme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.calendar_month_rounded,
                        color: theme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(summary.month,
                            style: AppTextStyles.subheading()),
                        const SizedBox(height: 2),
                        Text(
                          '${summary.bills.length} categor${summary.bills.length == 1 ? 'y' : 'ies'} · ${AppUtils.formatCurrency(summary.totalAmount)} total',
                          style: AppTextStyles.caption(),
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
                          color: statusColor.withOpacity(0.1),
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
                        style: AppTextStyles.caption(),
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
                        style: AppTextStyles.caption(),
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: AppTextStyles.caption(color: theme.primary)
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppColors.lightGray,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          paidCount == total && total > 0
                              ? AppColors.green
                              : theme.primary),
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
                                  color: theme.primary)),
                          const SizedBox(width: 2),
                          Icon(Icons.chevron_right_rounded,
                              color: theme.primary, size: 16),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption()),
        Text(value,
            style: AppTextStyles.caption(color: color)
                .copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
