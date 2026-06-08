import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bill_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/common_button.dart';

class IPaidScreen extends StatefulWidget {
  const IPaidScreen({super.key});

  @override
  State<IPaidScreen> createState() => _IPaidScreenState();
}

class _IPaidScreenState extends State<IPaidScreen> {
  String? _selectedBillId;
  final _txnCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _txnCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedBillId == null) {
      AppUtils.showSnackBar(context, 'Please select a bill', isError: true);
      return;
    }

    final confirm = await AppUtils.showConfirmDialog(
      context,
      title: 'Confirm Payment',
      message:
          'Are you sure you want to report this as paid?\n\nThe admin will verify your payment.',
      confirmText: 'Yes, I Paid',
      confirmColor: AppColors.paid,
    );
    if (confirm != true) return;

    setState(() => _isSubmitting = true);
    final auth = context.read<AuthProvider>();
    final userId = auth.currentUser?.id ?? 'u3';
    final billProvider = context.read<BillProvider>();
    final txnId =
        _txnCtrl.text.trim().isEmpty ? null : _txnCtrl.text.trim();

    await billProvider.userReportPaid(_selectedBillId!, userId,
        transactionId: txnId);

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _selectedBillId = null;
      _txnCtrl.clear();
    });
    _showSuccessDialog();
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFF0FDF4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: AppColors.paid, size: 44),
              ),
              const SizedBox(height: 18),
              Text('Payment Reported!',
                  style: AppTextStyles.heading3(
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text(
                'Your payment has been reported. The admin will verify and update your status.',
                style: AppTextStyles.bodyMedium(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              CommonButton(
                text: 'Done',
                backgroundColor: AppColors.paid,
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final userId = auth.currentUser?.id ?? 'u3';
    final billProvider = context.watch<BillProvider>();
    final theme = RoleTheme.of(UserRole.user);

    final pendingViews =
        billProvider.userBillViews(userId).where((v) => !v.payment.isPaid).toList();

    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Report Payment',
            style: AppTextStyles.heading3(color: Colors.white)),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: theme.gradient,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: theme.gradient,
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white, size: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Report Payment',
                          style: AppTextStyles.subheading(
                              color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(
                        'Already paid offline? Report it here so the admin can verify.',
                        style: AppTextStyles.caption(
                            color: Colors.white.withOpacity(0.85)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          if (pendingViews.isEmpty)
            const EmptyState(
              title: 'No Pending Bills',
              subtitle: 'All your bills are paid. Great job!',
              icon: Icons.check_circle_outline,
            )
          else ...[
            Text('Select Bill to Report', style: AppTextStyles.heading3()),
            const SizedBox(height: 14),

            ...pendingViews.map((view) {
              final isSelected = _selectedBillId == view.bill.id;
              final bill = view.bill;
              final payment = view.payment;
              return GestureDetector(
                onTap: () =>
                    setState(() => _selectedBillId = bill.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.primary.withOpacity(0.08)
                        : AppColors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? theme.primary
                          : Colors.transparent,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (payment.isOverdue
                                  ? AppColors.overdue
                                  : theme.primary)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.receipt_outlined,
                            color: payment.isOverdue
                                ? AppColors.overdue
                                : theme.primary,
                            size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(bill.title,
                                style: AppTextStyles.subheading()),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    'Due: ${AppUtils.formatDate(bill.dueDate)}',
                                    style: AppTextStyles.caption(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (payment.isOverdue) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.overdue
                                          .withOpacity(0.1),
                                      borderRadius:
                                          BorderRadius.circular(4),
                                    ),
                                    child: Text('Overdue',
                                        style: AppTextStyles.caption(
                                            color: AppColors.overdue)),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${AppUtils.formatCurrency(bill.totalAmount)} ÷ ${bill.totalFlats} flats',
                              style: AppTextStyles.caption(),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            AppUtils.formatCurrency(bill.perFlatShare),
                            style: AppTextStyles.subheading(),
                          ),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.primary
                                  : AppColors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? theme.primary
                                    : Colors.grey.shade300,
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 14)
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 16),

            Text('Transaction ID (Optional)',
                style: AppTextStyles.label(color: AppColors.textPrimary)
                    .copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _txnCtrl,
              style: AppTextStyles.bodyLarge(),
              decoration: InputDecoration(
                hintText: 'Enter UPI/bank reference ID',
                hintStyle: AppTextStyles.bodyMedium(),
                prefixIcon: const Icon(Icons.tag_outlined, size: 20),
              ),
            ),

            const SizedBox(height: 28),

            CommonButton(
              text: 'I Have Paid',
              gradient: theme.gradient,
              icon: Icons.check_circle_outline,
              isLoading: _isSubmitting,
              onPressed: _submit,
            ),

            const SizedBox(height: 12),
            Center(
              child: Text(
                'Admin will verify and update your status.',
                style: AppTextStyles.caption(),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    ), // end body SingleChildScrollView
    ); // end Scaffold
  }
}
