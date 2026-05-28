import 'package:flutter/material.dart';
import '../providers/bill_provider.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/app_utils.dart';
import 'status_chip.dart';

/// Displays a single bill from the resident's perspective.
/// Shows the per-flat share, bill split info, and payment status.
class BillCard extends StatelessWidget {
  final UserBillView view;
  final VoidCallback? onTap;
  final Widget? trailing;

  const BillCard({
    super.key,
    required this.view,
    this.onTap,
    this.trailing,
  });

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

  Color get _categoryColor {
    switch (view.bill.category) {
      case 'Maintenance':
        return AppColors.blue;
      case 'Utilities':
        return AppColors.teal;
      case 'Parking':
        return AppColors.purple;
      case 'Amenities':
        return AppColors.green;
      case 'Security':
        return AppColors.pending;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bill = view.bill;
    final payment = view.payment;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: payment.isOverdue
              ? Border.all(color: AppColors.overdue.withOpacity(0.25))
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _categoryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_categoryIcon, color: _categoryColor, size: 20),
                ),
                const SizedBox(width: 14),

                // Left content — title + dates
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bill.title,
                        style: AppTextStyles.subheading(
                            color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        bill.month,
                        style: AppTextStyles.caption(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      _DateRow(
                        icon: Icons.calendar_today_outlined,
                        iconColor: AppColors.textSecondary,
                        label: 'Due: ${AppUtils.formatDate(bill.dueDate)}',
                        labelColor: null,
                      ),
                      if (payment.paidDate != null) ...[
                        const SizedBox(height: 3),
                        _DateRow(
                          icon: Icons.check_circle_outline,
                          iconColor: AppColors.paid,
                          label:
                              'Paid: ${AppUtils.formatDate(payment.paidDate!)}',
                          labelColor: AppColors.paid,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Right side — share amount + status
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      AppUtils.formatCurrency(bill.perFlatShare),
                      style: AppTextStyles.subheading(
                          color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    trailing ?? StatusChip(status: payment.status),
                  ],
                ),
              ],
            ),

            // Bill split info row
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.lightGray.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline,
                      size: 12, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '${AppUtils.formatCurrency(bill.totalAmount)} ÷ ${bill.totalFlats} flats = ${AppUtils.formatCurrency(bill.perFlatShare)} your share',
                      style: AppTextStyles.caption(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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

class _DateRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color? labelColor;

  const _DateRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: iconColor),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: AppTextStyles.caption(color: labelColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
