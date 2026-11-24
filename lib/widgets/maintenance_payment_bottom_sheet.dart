import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/bill_model.dart';
import '../providers/bill_provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/role_theme.dart';
import '../core/utils/app_utils.dart';
import 'app_text_field.dart';

/// Bottom sheet shown to the president to record a payment for a resident.
class MaintenancePaymentBottomSheet extends StatefulWidget {
  final BillPayment payment;
  final BillModel bill;
  final String residentName;
  final VoidCallback? onSuccess;

  const MaintenancePaymentBottomSheet({
    super.key,
    required this.payment,
    required this.bill,
    required this.residentName,
    this.onSuccess,
  });

  @override
  State<MaintenancePaymentBottomSheet> createState() =>
      _MaintenancePaymentBottomSheetState();
}

class _MaintenancePaymentBottomSheetState
    extends State<MaintenancePaymentBottomSheet> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isLoading = false;

  // ── Computed amounts ────────────────────────────────────────────────────────

  double get _monthlyCharge =>
      widget.payment.amount ?? widget.bill.amountForUser(widget.payment.userId);

  double get _carryForward => widget.payment.carryForwardAmount;

  double get _totalOwed => _monthlyCharge + _carryForward;

  double get _alreadyPaid => widget.payment.paidAmountPaise / 100.0;

  double get _remaining => (_totalOwed - _alreadyPaid).clamp(0.0, _totalOwed);

  double get _enteredAmount {
    final raw = double.tryParse(_amountController.text.trim());
    return raw != null && raw > 0 ? raw : 0.0;
  }

  double get _outstandingAfter =>
      (_remaining - _enteredAmount).clamp(0.0, _remaining);

  bool get _isFullPayment =>
      (_enteredAmount - _remaining).abs() < 0.01;

  @override
  void initState() {
    super.initState();
    _amountController.text = _remaining.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ── Validation ──────────────────────────────────────────────────────────────

  String? _validateAmount() {
    final text = _amountController.text.trim();
    if (text.isEmpty) return 'Please enter an amount';
    final val = double.tryParse(text);
    if (val == null || val <= 0) return 'Enter a valid amount greater than ₹0';
    if (val > _remaining) {
      return 'Amount cannot exceed ${AppUtils.formatCurrency(_remaining)}';
    }
    return null;
  }

  // ── Action ──────────────────────────────────────────────────────────────────

  Future<void> _confirm() async {
    final error = _validateAmount();
    if (error != null) {
      AppUtils.showSnackBar(context, error, isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final paidPaise = (_enteredAmount * 100).round();
      await context.read<BillProvider>().adminMarkPartialPayment(
            billId: widget.payment.billId,
            userId: widget.payment.userId,
            paidAmountPaise: paidPaise,
            notes: _notesController.text.trim().isNotEmpty
                ? _notesController.text.trim()
                : null,
          );
      if (!mounted) return;
      final msg = _isFullPayment
          ? 'Payment recorded successfully!'
          : 'Partial payment of ${AppUtils.formatCurrency(_enteredAmount)} recorded!';
      AppUtils.showSnackBar(context, msg, color: AppColors.paid);
      Navigator.pop(context);
      widget.onSuccess?.call();
    } catch (e) {
      if (!mounted) return;
      AppUtils.showSnackBar(context, 'Failed to record payment. Try again.',
          isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = RoleTheme.of(UserRole.president);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = theme.effectivePrimary(context);

    return SafeArea(
      top: false,
      child: Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Gradient header ──────────────────────────────────────────────
            _buildHeader(theme),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Resident + bill info card ────────────────────────────
                  _buildInfoCard(cs, isDark, accent),
                  const SizedBox(height: 20),

                  // ── Amount section ───────────────────────────────────────
                  _buildAmountSection(cs, isDark, accent),
                  const SizedBox(height: 16),

                  // ── Notes ────────────────────────────────────────────────
                  AppTextField(
                    label: 'Notes (optional)',
                    controller: _notesController,
                    maxLines: 2,
                    prefixIcon: const Icon(Icons.notes_outlined),
                    focusColor: accent,
                  ),
                  const SizedBox(height: 24),

                  // ── Confirm button ───────────────────────────────────────
                  _buildConfirmButton(theme),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(RoleTheme theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: theme.gradient,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.payments_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Record Payment',
                      style: AppTextStyles.heading3(color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.bill.month,
                      style: AppTextStyles.caption(
                          color: Colors.white.withValues(alpha: 0.75)),
                    ),
                  ],
                ),
              ),
              // Amount badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  AppUtils.formatCurrency(_remaining),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Info card ────────────────────────────────────────────────────────────────

  Widget _buildInfoCard(ColorScheme cs, bool isDark, Color accent) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceVariant
            : accent.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          // Resident + flat
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      widget.residentName.isNotEmpty
                          ? widget.residentName.trim()[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.residentName,
                        style: AppTextStyles.bodyMedium(color: cs.onSurface)
                            .copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.home_outlined,
                              size: 13, color: cs.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            'Flat ${widget.payment.unitNumber}',
                            style: AppTextStyles.caption(
                                color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: accent.withValues(alpha: 0.12)),

          // Amount breakdown
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _infoRow(cs, 'Monthly Charge',
                    AppUtils.formatCurrency(_monthlyCharge)),
                if (_carryForward > 0) ...[
                  const SizedBox(height: 8),
                  _infoRow(
                    cs,
                    'Previous Outstanding',
                    AppUtils.formatCurrency(_carryForward),
                    valueColor: AppColors.overdue,
                  ),
                ],
                const SizedBox(height: 8),
                _infoRow(
                  cs,
                  'Total Due',
                  AppUtils.formatCurrency(_totalOwed),
                  isBold: true,
                ),
                if (widget.payment.isPartiallyPaid) ...[
                  const SizedBox(height: 8),
                  _infoRow(
                    cs,
                    'Already Paid',
                    AppUtils.formatCurrency(_alreadyPaid),
                    valueColor: AppColors.paid,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Divider(
                        height: 1,
                        color: cs.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  _infoRow(
                    cs,
                    'Remaining Balance',
                    AppUtils.formatCurrency(_remaining),
                    isBold: true,
                    valueColor: accent,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    ColorScheme cs,
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isBold
              ? AppTextStyles.bodySmall(color: cs.onSurface)
                  .copyWith(fontWeight: FontWeight.w600)
              : AppTextStyles.bodySmall(color: cs.onSurfaceVariant),
        ),
        Text(
          value,
          style: isBold
              ? AppTextStyles.bodyMedium(color: valueColor ?? cs.onSurface)
                  .copyWith(fontWeight: FontWeight.w700)
              : AppTextStyles.bodySmall(color: valueColor ?? cs.onSurface)
                  .copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  // ── Amount section ───────────────────────────────────────────────────────────

  Widget _buildAmountSection(ColorScheme cs, bool isDark, Color accent) {
    final isFullAmount = _isFullPayment || _enteredAmount == 0;
    final badgeColor = isFullAmount ? AppColors.paid : AppColors.pending;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Payment Amount',
              style: AppTextStyles.subheading(color: cs.onSurface),
            ),
            const Spacer(),
            if (_enteredAmount > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: badgeColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  isFullAmount ? 'Full Payment' : 'Partial Payment',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: badgeColor,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        // Amount input
        AppTextField(
          label: 'Amount (₹)',
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          focusColor: accent,
          prefixIcon: const Icon(Icons.currency_rupee_rounded),
          onChanged: (_) => setState(() {}),
        ),

        // Outstanding preview
        if (_enteredAmount > 0 &&
            _enteredAmount < _remaining &&
            _outstandingAfter > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.pending.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.pending.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 15, color: AppColors.pending),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppColors.pending),
                      children: [
                        TextSpan(
                          text:
                              '${AppUtils.formatCurrency(_outstandingAfter)} ',
                          style:
                              const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const TextSpan(
                            text: 'will carry forward to the next month'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ── Confirm button ───────────────────────────────────────────────────────────

  Widget _buildConfirmButton(RoleTheme theme) {
    final isPartial = !_isFullPayment && _enteredAmount > 0;
    final buttonColor = isPartial ? AppColors.pending : AppColors.paid;
    final label =
        isPartial ? 'Record Partial Payment' : 'Confirm Full Payment';

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _isLoading ? null : _confirm,
        style: FilledButton.styleFrom(
          backgroundColor: buttonColor,
          disabledBackgroundColor: buttonColor.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isPartial
                        ? Icons.pie_chart_rounded
                        : Icons.check_circle_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: AppTextStyles.bodyMedium(color: Colors.white)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Shows the [MaintenancePaymentBottomSheet] as a modal bottom sheet.
void showMaintenancePaymentSheet(
  BuildContext context, {
  required BillPayment payment,
  required BillModel bill,
  required String residentName,
  VoidCallback? onSuccess,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: MaintenancePaymentBottomSheet(
        payment: payment,
        bill: bill,
        residentName: residentName,
        onSuccess: onSuccess,
      ),
    ),
  );
}
