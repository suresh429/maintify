import 'package:flutter/material.dart';
import '../models/bill_model.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

class StatusChip extends StatelessWidget {
  final String status;

  const StatusChip({super.key, required this.status});

  Color get _bgColor {
    switch (status) {
      case BillStatus.paid:
        return AppColors.paid.withOpacity(0.12);
      case BillStatus.overdue:
        return AppColors.overdue.withOpacity(0.12);
      default:
        return AppColors.pending.withOpacity(0.12);
    }
  }

  Color get _textColor {
    switch (status) {
      case BillStatus.paid:
        return AppColors.paid;
      case BillStatus.overdue:
        return AppColors.overdue;
      default:
        return AppColors.pending;
    }
  }

  IconData get _icon {
    switch (status) {
      case BillStatus.paid:
        return Icons.check_circle_outline;
      case BillStatus.overdue:
        return Icons.error_outline;
      default:
        return Icons.schedule_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, color: _textColor, size: 13),
          const SizedBox(width: 4),
          Text(
            status,
            style: AppTextStyles.caption(color: _textColor)
                .copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
