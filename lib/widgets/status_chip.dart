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
        return AppColors.paid.withValues(alpha: 0.12);
      case BillStatus.overdue:
        return AppColors.overdue.withValues(alpha: 0.12);
      case BillStatus.pendingApproval:
        return const Color(0xFFF59E0B).withValues(alpha: 0.13);
      default:
        return AppColors.pending.withValues(alpha: 0.12);
    }
  }

  Color get _textColor {
    switch (status) {
      case BillStatus.paid:
        return AppColors.paid;
      case BillStatus.overdue:
        return AppColors.overdue;
      case BillStatus.pendingApproval:
        return const Color(0xFFD97706);
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
      case BillStatus.pendingApproval:
        return Icons.hourglass_top_rounded;
      default:
        return Icons.schedule_outlined;
    }
  }

  String get _label {
    if (status == BillStatus.pendingApproval) return 'Awaiting Approval';
    return status;
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
            _label,
            style: AppTextStyles.caption(color: _textColor)
                .copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
