import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_fund_provider.dart';
import '../../models/fund_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../widgets/app_text_field.dart';

Future<void> showAddFundExpenseSheet(BuildContext context, String aptId) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddFundExpenseSheet(aptId: aptId),
  );
}

// Keep old class name so any existing Navigator.push callers compile.
class AddFundExpenseScreen extends StatelessWidget {
  final String aptId;
  const AddFundExpenseScreen({super.key, required this.aptId});

  @override
  Widget build(BuildContext context) => _AddFundExpenseSheet(aptId: aptId);
}

// ─────────────────────────────────────────────────────────────────────────────

class _AddFundExpenseSheet extends StatefulWidget {
  final String aptId;
  const _AddFundExpenseSheet({required this.aptId});

  @override
  State<_AddFundExpenseSheet> createState() => _AddFundExpenseSheetState();
}

class _AddFundExpenseSheetState extends State<_AddFundExpenseSheet> {
  final _formKey     = GlobalKey<FormState>();
  final _amountCtrl  = TextEditingController();
  final _descCtrl    = TextEditingController();
  final _receiptCtrl = TextEditingController();
  bool  _saving      = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _receiptCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final fund = context.read<CommunityFundProvider>();

    final amountRs    = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final amountPaise = (amountRs * 100).round();
    final balance     = fund.summary?.balancePaise ?? 0;

    if (amountPaise > balance) {
      AppUtils.showSnackBar(
        context,
        'Insufficient balance. Available: ${AppUtils.formatCurrency(balance / 100)}',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await fund.addExpense(
        aptId:         widget.aptId,
        amountPaise:   amountPaise,
        description:   _descCtrl.text.trim(),
        category:      FundCategory.general,
        createdBy:     auth.currentUser?.id   ?? '',
        createdByName: auth.currentUser?.name ?? '',
        receiptNote:   _receiptCtrl.text.trim().isEmpty
            ? null
            : _receiptCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        AppUtils.showSnackBar(context, 'Expense recorded successfully!',
            color: AppColors.paid);
      }
    } catch (e) {
      if (mounted) AppUtils.showSnackBar(context, 'Failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme   = RoleTheme.of(UserRole.president);
    final fund    = context.watch<CommunityFundProvider>();
    final cs      = Theme.of(context).colorScheme;
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final accent  = theme.effectivePrimary(context);
    final balance = fund.summary?.balance ?? 0;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : cs.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Handle ─────────────────────────────────────────────
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: cs.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),

                  // ── Header ─────────────────────────────────────────────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.overdue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                            Icons.remove_circle_outline_rounded,
                            color: AppColors.overdue,
                            size: 22),
                      ),
                      const SizedBox(width: 12),
                      Text('Add Expense',
                          style: AppTextStyles.heading3(color: cs.onSurface)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Text(
                      'Record an expense deducted from the community fund.',
                      style: AppTextStyles.caption(
                          color: cs.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Balance banner ─────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.overdue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.overdue.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined,
                            color: AppColors.overdue, size: 16),
                        const SizedBox(width: 8),
                        Text('Available: ',
                            style: AppTextStyles.caption(
                                color: cs.onSurfaceVariant)),
                        Text(
                          AppUtils.formatCurrency(balance),
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.overdue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Amount ─────────────────────────────────────────────
                  AppTextField(
                    controller: _amountCtrl,
                    label: 'Amount (₹)',
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    focusColor: accent,
                    validator: (v) {
                      final val = double.tryParse(v?.trim() ?? '');
                      if (val == null || val <= 0) {
                        return 'Enter a valid amount';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // ── Description ────────────────────────────────────────
                  AppTextField(
                    controller: _descCtrl,
                    label: 'Description',
                    hint: 'e.g. Replaced lobby light fixtures',
                    maxLines: 2,
                    focusColor: accent,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Enter a description'
                        : null,
                  ),
                  const SizedBox(height: 14),

                  // ── Receipt / note ─────────────────────────────────────
                  AppTextField(
                    controller: _receiptCtrl,
                    label: 'Receipt / Note (optional)',
                    hint: 'e.g. Bill #5678',
                    focusColor: accent,
                  ),
                  const SizedBox(height: 24),

                  // ── Submit ─────────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.overdue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text('Record Expense',
                              style: AppTextStyles.buttonText(
                                  color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
