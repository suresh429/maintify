import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bill_provider.dart';
import '../../providers/user_provider.dart';

/// Community payment board — horizontal month tabs with resident payment rows.
/// Does NOT display payment screenshots, bank details, UPI refs, or transaction IDs.
class PaymentBoardScreen extends StatefulWidget {
  const PaymentBoardScreen({super.key});

  @override
  State<PaymentBoardScreen> createState() => _PaymentBoardScreenState();
}

class _PaymentBoardScreenState extends State<PaymentBoardScreen> {
  int _selectedIndex = 0;
  final _tabScrollCtrl = ScrollController();

  @override
  void dispose() {
    _tabScrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final aptId = auth.currentUser?.apartmentId ?? '';
    final isWeb = MediaQuery.sizeOf(context).width >= 600;
    final accent = RoleTheme.of(UserRole.resident).effectivePrimary(context);

    return Consumer2<BillProvider, UserProvider>(
      builder: (_, billProv, userProv, __) {
        final summaries = billProv.monthlyBillsForApartment(aptId);

        if (summaries.isEmpty) {
          return _EmptyPaymentBoard();
        }

        // Clamp selected index in case summaries shrank
        final safeIndex = _selectedIndex.clamp(0, summaries.length - 1);
        final selected = summaries[safeIndex];

        return Column(
          children: [
            // ── Month tabs ──────────────────────────────────────────────────
            _MonthTabBar(
              summaries: summaries,
              selectedIndex: safeIndex,
              scrollController: _tabScrollCtrl,
              accent: accent,
              onSelected: (i) => setState(() => _selectedIndex = i),
            ),

            // ── Selected month summary header ───────────────────────────────
            _MonthSummaryHeader(summary: selected, accent: accent),

            // ── Resident rows ───────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                    isWeb ? 24.0 : 8.0, 0, isWeb ? 24.0 : 8.0, 24),
                children: () {
                  final flats = selected.flatList;
                  if (flats.isEmpty) {
                    return [
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'No payment data available',
                            style: AppTextStyles.bodySmall(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                          ),
                        ),
                      ),
                    ];
                  }
                  final now = DateTime.now();
                  return flats.map((flat) {
                    final payments = selected.allPayments
                        .where((p) =>
                            p.userId == flat.userId &&
                            selected.bills.any((b) => b.id == p.billId))
                        .toList();

                    _PaymentStatus status;
                    DateTime? paidDate;
                    if (payments.isEmpty) {
                      status = _PaymentStatus.pending;
                    } else if (payments.every((p) => p.isPaid)) {
                      status = _PaymentStatus.paid;
                      paidDate = selected.userPaidDate(flat.userId);
                    } else if (payments.any((p) => p.isPendingApproval)) {
                      status = _PaymentStatus.pendingVerification;
                    } else if (payments.any((p) =>
                        !p.isPaid &&
                        !p.isPendingApproval &&
                        now.isAfter(selected.dueDate))) {
                      status = _PaymentStatus.overdue;
                    } else {
                      status = _PaymentStatus.pending;
                    }

                    final name =
                        userProv.findById(flat.userId)?.name ?? 'Resident';
                    return _FlatPaymentRow(
                      unitNumber: flat.unitNumber,
                      residentName: name,
                      status: status,
                      paidDate: paidDate,
                      amount: selected.perFlatShare,
                    );
                  }).toList();
                }(),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Month tab bar ─────────────────────────────────────────────────────────────

class _MonthTabBar extends StatelessWidget {
  final List<MonthlyBillSummary> summaries;
  final int selectedIndex;
  final ScrollController scrollController;
  final Color accent;
  final ValueChanged<int> onSelected;

  const _MonthTabBar({
    required this.summaries,
    required this.selectedIndex,
    required this.scrollController,
    required this.accent,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: 52,
      child: ListView.builder(
        controller: scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        itemCount: summaries.length,
        itemBuilder: (_, i) {
          final isSelected = i == selectedIndex;
          final s = summaries[i];
          // Abbreviate: "August 2026" → "Aug 2026"
          final parts = s.month.split(' ');
          final label = parts.length == 2
              ? '${parts[0].substring(0, 3)} ${parts[1]}'
              : s.month;
          final allPaid =
              s.fullyPaidFlats == s.eligibleFlats && s.eligibleFlats > 0;

          return GestureDetector(
            onTap: () => onSelected(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? accent
                    : cs.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
                border: isSelected
                    ? null
                    : Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (allPaid) ...[
                    Icon(Icons.check_circle_rounded,
                        size: 12,
                        color: isSelected ? Colors.white : AppColors.paid),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Month summary header ──────────────────────────────────────────────────────

class _MonthSummaryHeader extends StatelessWidget {
  final MonthlyBillSummary summary;
  final Color accent;

  const _MonthSummaryHeader({required this.summary, required this.accent});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paidCount = summary.fullyPaidFlats;
    final total = summary.eligibleFlats;
    final allPaid = paidCount == total && total > 0;
    final statusColor = allPaid ? AppColors.paid : accent;
    final progress = total == 0 ? 0.0 : paidCount / total;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
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
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  allPaid
                      ? Icons.check_circle_rounded
                      : Icons.calendar_month_outlined,
                  color: statusColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(summary.month,
                        style: AppTextStyles.subheading(color: cs.onSurface)),
                    Text(
                      'Due: ${AppUtils.formatDate(summary.dueDate)}',
                      style:
                          AppTextStyles.caption(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$paidCount / $total paid',
                    style: AppTextStyles.caption(color: statusColor)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    AppUtils.formatCurrency(summary.totalAmount),
                    style:
                        AppTextStyles.caption(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: cs.outlineVariant,
              valueColor: AlwaysStoppedAnimation<Color>(
                  allPaid ? AppColors.paid : accent),
              minHeight: 6,
            ),
          ),
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
  final double amount;

  const _FlatPaymentRow({
    required this.unitNumber,
    required this.residentName,
    required this.status,
    required this.amount,
    this.paidDate,
  });

  String get _label {
    switch (status) {
      case _PaymentStatus.paid:
        return 'Paid';
      case _PaymentStatus.pendingVerification:
        return 'Verifying';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Unit badge
          Container(
            width: 42,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              unitNumber,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name + amount
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  residentName,
                  style: AppTextStyles.bodySmall(color: cs.onSurface)
                      .copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (paidDate != null)
                  Text(
                    'Paid on ${AppUtils.formatDate(paidDate!)}',
                    style: AppTextStyles.caption(color: AppColors.paid),
                  )
                else
                  Text(
                    AppUtils.formatCurrency(amount),
                    style: AppTextStyles.caption(color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),

          // Status chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _statusColor,
              ),
            ),
          ),
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
              style: AppTextStyles.bodySmall(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
