import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_utils.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bill_provider.dart';
import '../../providers/user_provider.dart';

/// Community payment board — shows all apartment payments grouped by month.
/// Does NOT display payment screenshots, bank details, UPI refs, or transaction IDs.
class PaymentBoardScreen extends StatelessWidget {
  const PaymentBoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final aptId = auth.currentUser?.apartmentId ?? '';

    final isWeb = MediaQuery.sizeOf(context).width >= 600;
    final hPad = isWeb ? 24.0 : 16.0;

    return Consumer2<BillProvider, UserProvider>(
      builder: (_, billProv, userProv, __) {
        final summaries = billProv.monthlyBillsForApartment(aptId);

        if (summaries.isEmpty) {
          return _EmptyPaymentBoard();
        }

        return ListView.builder(
          padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 24),
          itemCount: summaries.length,
          itemBuilder: (_, i) {
            final card = _MonthCard(summary: summaries[i], userProv: userProv);
            return isWeb
                ? Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 960),
                      child: card,
                    ),
                  )
                : card;
          },
        );
      },
    );
  }
}

// ── Month Card ────────────────────────────────────────────────────────────────

class _MonthCard extends StatefulWidget {
  final MonthlyBillSummary summary;
  final UserProvider userProv;

  const _MonthCard({required this.summary, required this.userProv});

  @override
  State<_MonthCard> createState() => _MonthCardState();
}

class _MonthCardState extends State<_MonthCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final summary = widget.summary;
    final now = DateTime.now();

    final paidCount = summary.fullyPaidFlats;
    final totalEligible = summary.eligibleFlats;
    final allPaid = paidCount == totalEligible && totalEligible > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month header
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft:
                      _expanded ? Radius.zero : const Radius.circular(16),
                  bottomRight:
                      _expanded ? Radius.zero : const Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (allPaid ? AppColors.paid : AppColors.pending)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      allPaid
                          ? Icons.check_circle_rounded
                          : Icons.calendar_month_outlined,
                      color: allPaid ? AppColors.paid : AppColors.pending,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.month,
                          style: AppTextStyles.subheading(color: cs.onSurface),
                        ),
                        Text(
                          'Due: ${AppUtils.formatDate(summary.dueDate)}',
                          style: AppTextStyles.caption(
                              color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$paidCount / $totalEligible paid',
                        style: AppTextStyles.caption(
                          color: allPaid ? AppColors.paid : AppColors.pending,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        AppUtils.formatCurrency(summary.totalAmount),
                        style: AppTextStyles.caption(
                            color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: cs.onSurfaceVariant,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Flat rows
          if (_expanded) ...[
            const Divider(height: 1),
            ...() {
              final flats = summary.flatList;
              if (flats.isEmpty) {
                return [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No payment data available',
                      style: AppTextStyles.bodySmall(
                          color: cs.onSurfaceVariant),
                    ),
                  ),
                ];
              }
              return flats.map((flat) {
                final payment = summary.allPayments
                    .where((p) =>
                        p.userId == flat.userId &&
                        summary.bills.any((b) => b.id == p.billId))
                    .toList();

                // Determine consolidated status for this flat
                _PaymentStatus status;
                DateTime? paidDate;

                if (payment.isEmpty) {
                  status = _PaymentStatus.pending;
                } else if (payment.every((p) => p.isPaid)) {
                  status = _PaymentStatus.paid;
                  paidDate = summary.userPaidDate(flat.userId);
                } else if (payment.any((p) => p.isPendingApproval)) {
                  status = _PaymentStatus.pendingVerification;
                } else if (payment.any((p) =>
                    !p.isPaid &&
                    !p.isPendingApproval &&
                    now.isAfter(summary.dueDate))) {
                  status = _PaymentStatus.overdue;
                } else {
                  status = _PaymentStatus.pending;
                }

                final residentName =
                    widget.userProv.findById(flat.userId)?.name ?? 'Resident';

                return _FlatPaymentRow(
                  unitNumber: flat.unitNumber,
                  residentName: residentName,
                  status: status,
                  paidDate: paidDate,
                );
              }).toList();
            }(),
          ],
        ],
      ),
    );
  }
}

// ── Flat payment row ──────────────────────────────────────────────────────────

enum _PaymentStatus { paid, pendingVerification, overdue, pending }

class _FlatPaymentRow extends StatelessWidget {
  final String unitNumber;
  final String residentName;
  final _PaymentStatus status;
  final DateTime? paidDate;

  const _FlatPaymentRow({
    required this.unitNumber,
    required this.residentName,
    required this.status,
    this.paidDate,
  });

  String get _label {
    switch (status) {
      case _PaymentStatus.paid:
        return 'Paid';
      case _PaymentStatus.pendingVerification:
        return 'Pending Verification';
      case _PaymentStatus.overdue:
        return 'Overdue';
      case _PaymentStatus.pending:
        return 'Pending';
    }
  }

  Color get _statusColor {
    switch (status) {
      case _PaymentStatus.paid:
        return AppColors.paid;
      case _PaymentStatus.pendingVerification:
        return const Color(0xFFD97706);
      case _PaymentStatus.overdue:
        return AppColors.overdue;
      case _PaymentStatus.pending:
        return AppColors.pending;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.4),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Flat number badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              unitNumber,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Resident name
          Expanded(
            child: Text(
              residentName,
              style: AppTextStyles.bodySmall(color: cs.onSurface)
                  .copyWith(fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Status chip
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _statusColor,
              ),
            ),
          ),

          // Paid date
          if (paidDate != null) ...[
            const SizedBox(width: 8),
            Text(
              AppUtils.formatDate(paidDate!),
              style: AppTextStyles.caption(color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyPaymentBoard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 64,
                color: AppColors.pending.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('No Bills Yet',
                style: AppTextStyles.heading3(color: cs.onSurface)),
            const SizedBox(height: 8),
            Text(
              'Payment records will appear here\nonce the president creates a bill.',
              textAlign: TextAlign.center,
              style:
                  AppTextStyles.bodySmall(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
