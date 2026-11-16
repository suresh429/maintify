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

class AddFundExpenseScreen extends StatefulWidget {
  final String aptId;
  const AddFundExpenseScreen({super.key, required this.aptId});

  @override
  State<AddFundExpenseScreen> createState() => _AddFundExpenseScreenState();
}

class _AddFundExpenseScreenState extends State<AddFundExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _receiptCtrl = TextEditingController();
  String _category = FundCategory.general;
  bool _saving = false;

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

    final amountRs = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final amountPaise = (amountRs * 100).round();

    // Check balance
    final balance = fund.summary?.balancePaise ?? 0;
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
        aptId: widget.aptId,
        amountPaise: amountPaise,
        description: _descCtrl.text.trim(),
        category: _category,
        createdBy: auth.currentUser?.id ?? '',
        createdByName: auth.currentUser?.name ?? '',
        receiptNote: _receiptCtrl.text.trim().isEmpty
            ? null
            : _receiptCtrl.text.trim(),
      );
      if (mounted) {
        AppUtils.showSnackBar(
          context,
          'Expense recorded successfully!',
          color: AppColors.paid,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) AppUtils.showSnackBar(context, 'Failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = RoleTheme.of(UserRole.president);
    final fund = context.watch<CommunityFundProvider>();
    final cs = Theme.of(context).colorScheme;
    final accent = theme.effectivePrimary(context);
    final balance = fund.summary?.balance ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Add Expense',
            style: AppTextStyles.heading3(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: theme.gradient,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Balance chip
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.overdue.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.overdue.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined,
                      color: AppColors.overdue, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    'Available balance: ${AppUtils.formatCurrency(balance)}',
                    style: AppTextStyles.subheading(color: cs.onSurface)
                        .copyWith(fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Amount
            AppTextField(
              controller: _amountCtrl,
              label: 'Amount (₹)',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              focusColor: accent,
              validator: (v) {
                final val = double.tryParse(v?.trim() ?? '');
                if (val == null || val <= 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Category dropdown
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: InputDecoration(
                labelText: 'Category',
                labelStyle: TextStyle(color: cs.onSurfaceVariant),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: cs.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: accent, width: 2),
                ),
                filled: true,
                fillColor: cs.surfaceContainerLowest,
              ),
              items: FundCategory.all
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 14),

            // Description
            AppTextField(
              controller: _descCtrl,
              label: 'Description',
              hint: 'e.g. Replaced lobby light fixtures',
              maxLines: 2,
              focusColor: accent,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter a description' : null,
            ),
            const SizedBox(height: 14),

            // Receipt / note (optional)
            AppTextField(
              controller: _receiptCtrl,
              label: 'Receipt / Note (optional)',
              hint: 'e.g. Bill #5678',
              focusColor: accent,
            ),
            const SizedBox(height: 28),

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
                        style: AppTextStyles.buttonText(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
