import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bill_provider.dart';
import '../../providers/apartment_provider.dart';
import '../../models/bill_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../widgets/shimmer_loading.dart';

class IPaidScreen extends StatelessWidget {
  const IPaidScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    final billProvider = context.watch<BillProvider>();
    final theme = RoleTheme.of(UserRole.resident);
    final cs = Theme.of(context).colorScheme;

    final summaries = billProvider.userMonthlySummaries(user.id);

    final pending = summaries
        .where((s) =>
            s.status == BillStatus.pending || s.status == BillStatus.overdue)
        .toList();
    final inReview = summaries
        .where((s) => s.status == BillStatus.pendingApproval)
        .toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Mark as Paid',
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
      body: (pending.isEmpty && inReview.isEmpty)
          ? const EmptyState(
              title: 'No Pending Bills',
              subtitle: 'All your bills are paid. Great job!',
              icon: Icons.check_circle_outline,
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ── Awaiting Approval section ────────────────────────────
                if (inReview.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.hourglass_top_rounded,
                    label: 'Awaiting Approval',
                    color: const Color(0xFFD97706),
                  ),
                  const SizedBox(height: 10),
                  ...inReview.map((s) => _BillStatusCard(
                        summary: s,
                        cardStatus: _CardStatus.inReview,
                        onMarkPaid: null,
                        theme: theme,
                        cs: cs,
                        context: context,
                      )),
                  const SizedBox(height: 24),
                ],

                // ── Pending section ──────────────────────────────────────
                if (pending.isNotEmpty) ...[
                  _SectionHeader(
                    icon: Icons.receipt_long_outlined,
                    label: 'Bills to Mark as Paid',
                    color: theme.effectivePrimary(context),
                  ),
                  const SizedBox(height: 10),
                  ...pending.map((s) => _BillStatusCard(
                        summary: s,
                        cardStatus: _CardStatus.pending,
                        onMarkPaid: () => _showConfirmationDialog(
                          context,
                          summary: s,
                          userId: user.id,
                          unitNumber: user.unit,
                          aptId: user.apartmentId ?? '',
                          theme: theme,
                        ),
                        theme: theme,
                        cs: cs,
                        context: context,
                      )),
                ],
              ],
            ),
    );
  }

  Future<void> _showConfirmationDialog(
    BuildContext context, {
    required UserMonthlySummary summary,
    required String userId,
    required String unitNumber,
    required String aptId,
    required RoleTheme theme,
  }) async {
    final aptProvider = context.read<ApartmentProvider>();
    final presidentId = aptProvider.currentPresidentId(aptId) ?? '';

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 280),
      transitionBuilder: (ctx, anim, _, child) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: curved, child: child),
        );
      },
      pageBuilder: (ctx, _, __) => _ConfirmDialog(
        summary: summary,
        userId: userId,
        unitNumber: unitNumber,
        aptId: aptId,
        presidentId: presidentId,
        theme: theme,
      ),
    );
  }
}

// ── Section header ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 6),
        Text(label,
            style: AppTextStyles.label(color: color)
                .copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

enum _CardStatus { pending, inReview }

// ── Bill status card ────────────────────────────────────────────────────────

class _BillStatusCard extends StatelessWidget {
  final UserMonthlySummary summary;
  final _CardStatus cardStatus;
  final VoidCallback? onMarkPaid;
  final RoleTheme theme;
  final ColorScheme cs;
  final BuildContext context;

  const _BillStatusCard({
    required this.summary,
    required this.cardStatus,
    required this.onMarkPaid,
    required this.theme,
    required this.cs,
    required this.context,
  });

  @override
  Widget build(BuildContext ctx) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    final isOverdue = summary.status == BillStatus.overdue;
    final wasRejected =
        summary.views.any((v) => v.payment.wasRejected);

    final iconColor = cardStatus == _CardStatus.inReview
        ? const Color(0xFFD97706)
        : isOverdue
            ? AppColors.overdue
            : theme.effectivePrimary(ctx);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    cardStatus == _CardStatus.inReview
                        ? Icons.hourglass_top_rounded
                        : Icons.receipt_outlined,
                    color: iconColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.month,
                        style: AppTextStyles.subheading(color: cs.onSurface),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Due: ${AppUtils.formatDate(summary.dueDate)}',
                        style: AppTextStyles.caption(),
                      ),
                      if (wasRejected && cardStatus == _CardStatus.pending) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.info_outline,
                                size: 12, color: AppColors.overdue),
                            const SizedBox(width: 4),
                            Text(
                              'Previously rejected — please resubmit.',
                              style: AppTextStyles.caption(
                                  color: AppColors.overdue),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  AppUtils.formatCurrency(summary.totalAmount),
                  style: AppTextStyles.subheading(color: cs.onSurface)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),

          // Action area
          if (cardStatus == _CardStatus.inReview)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.hourglass_top_rounded,
                      size: 15, color: Color(0xFFD97706)),
                  const SizedBox(width: 6),
                  Text(
                    'Awaiting president approval',
                    style: AppTextStyles.caption(
                            color: const Color(0xFFD97706))
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding:
                  const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onMarkPaid,
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.effectivePrimary(ctx),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: Text('Mark as Paid',
                      style: AppTextStyles.buttonText()),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Confirmation dialog ─────────────────────────────────────────────────────

class _ConfirmDialog extends StatefulWidget {
  final UserMonthlySummary summary;
  final String userId;
  final String unitNumber;
  final String aptId;
  final String presidentId;
  final RoleTheme theme;

  const _ConfirmDialog({
    required this.summary,
    required this.userId,
    required this.unitNumber,
    required this.aptId,
    required this.presidentId,
    required this.theme,
  });

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  bool _submitting = false;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await context.read<BillProvider>().residentSubmitPaymentForMonth(
            month: widget.summary.month,
            aptId: widget.aptId,
            userId: widget.userId,
            presidentId: widget.presidentId,
            unitNumber: widget.unitNumber,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      AppUtils.showSnackBar(
        context,
        'Payment submitted for approval.',
        color: AppColors.paid,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppUtils.showSnackBar(context, 'Failed to submit. Try again.',
          isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Gradient icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: widget.theme.gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.payments_outlined,
                      color: Colors.white, size: 30),
                ),
                const SizedBox(height: 16),

                Text('Confirm Payment',
                    style: AppTextStyles.heading3(color: cs.onSurface)),
                const SizedBox(height: 8),

                // Amount chip
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.paid.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    AppUtils.formatCurrency(widget.summary.totalAmount),
                    style: AppTextStyles.subheading(color: AppColors.paid)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  'Confirm that you have paid your maintenance for ${widget.summary.month}.',
                  style: AppTextStyles.bodyMedium(color: cs.onSurface),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),

                // Notification note
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.notifications_outlined,
                          size: 15, color: cs.onSurface.withValues(alpha: 0.6)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'The president will be notified and will verify your payment.',
                          style: AppTextStyles.caption(
                              color: cs.onSurface.withValues(alpha: 0.7)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text('Cancel',
                            style: AppTextStyles.buttonText(
                                color: cs.onSurface)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _submitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              widget.theme.effectivePrimary(context),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
                              )
                            : Text('Submit',
                                style:
                                    AppTextStyles.buttonText()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
