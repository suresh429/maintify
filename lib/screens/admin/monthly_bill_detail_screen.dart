import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/bill_model.dart';
import '../../models/user_model.dart';
import '../../providers/bill_provider.dart';
import '../../providers/user_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/app_utils.dart';
import 'edit_bill_sheet.dart';

class MonthlyBillDetailScreen extends StatelessWidget {
  final MonthlyBillSummary summary;
  final String aptId;

  const MonthlyBillDetailScreen({
    super.key,
    required this.summary,
    required this.aptId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = RoleTheme.of(UserRole.admin);
    final billProvider = context.watch<BillProvider>();

    final fresh = billProvider.monthlyBillsForApartment(aptId).firstWhere(
          (s) => s.month == summary.month,
          orElse: () => summary,
        );
    final flats = fresh.flatList;

    // Total collected = sum of actual paid payment amounts
    final collectedAmount = fresh.allPayments
        .where((p) => p.isPaid)
        .fold(0.0, (s, p) => s + (p.amount ?? fresh.perFlatShare));
    final totalBilledAmount = fresh.allPayments
        .fold(0.0, (s, p) => s + (p.amount ?? fresh.perFlatShare));
    final pendingAmount = totalBilledAmount - collectedAmount;
    final collectionRate =
        totalBilledAmount == 0 ? 0.0 : collectedAmount / totalBilledAmount;

    // Get the raw bill document for edit/delete (first bill id in this month)
    final rawBillId = fresh.bills.isNotEmpty ? fresh.bills.first.id : null;
    final rawBill = rawBillId != null
        ? context.read<BillProvider>().rawBillById(rawBillId)
        : null;
    final residents =
        context.read<UserProvider>().membersForApartment(aptId);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(summary.month,
            style: AppTextStyles.heading3(color: Colors.white)),
        actions: [
          if (rawBill != null)
            IconButton(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
              onPressed: () => _showDetailBillActions(
                context,
                rawBill: rawBill,
                summary: summary,
                residents: residents,
                billProvider: context.read<BillProvider>(),
              ),
            ),
        ],
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
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                children: [
                  // ── Section 1: Hero Summary ──────────────────────────────
                  _buildHeroCard(theme, fresh),
                  const SizedBox(height: 14),

                  // ── Section 2: Category Breakdown ────────────────────────
                  _buildCategoryBreakdown(theme, fresh, context),
                  const SizedBox(height: 14),

                  // ── Section 3: Collection Progress ───────────────────────
                  _buildCollectionProgress(
                    theme,
                    fresh,
                    collectedAmount,
                    pendingAmount,
                    collectionRate,
                    totalBilledAmount,
                    context,
                  ),
                  const SizedBox(height: 16),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Flat-wise Status',
                        style: AppTextStyles.heading3()),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),

          // ── Section 4: Flat-wise Status ──────────────────────────────────
          //
          // Build a userId → actual amount map from stored payment docs.
          // Sums across all bills in the month (multi-bill months supported).
          // Falls back to bill.perFlatShare per payment for legacy records
          // that pre-date the per-user amount field.
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final flat = flats[i];
                final isPaid = fresh.isUserFullyPaid(flat.userId);
                final paidDate = fresh.userPaidDate(flat.userId);
                final userName = ctx.read<UserProvider>().findById(flat.userId)?.name;

                // Use the stored payment amount — single source of truth.
                // Avoids re-computing splits and correctly handles hybrid /
                // individual categories and excluded residents.
                final billById = {for (final b in fresh.bills) b.id: b};
                final userAmount = fresh.allPayments
                    .where((p) => p.userId == flat.userId)
                    .fold<double>(
                      0.0,
                      (sum, p) => sum + (p.amount ?? (billById[p.billId]?.perFlatShare ?? 0.0)),
                    );

                return Padding(
                  padding: EdgeInsets.fromLTRB(
                      16, 0, 16, i == flats.length - 1 ? 100 : 10),
                  child: _FlatPaymentCard(
                    unitNumber: flat.unitNumber,
                    userName: userName,
                    isPaid: isPaid,
                    paidDate: paidDate,
                    amount: userAmount,
                    theme: theme,
                    isLoading: billProvider.isLoading,
                    onMarkPaid: isPaid
                        ? null
                        : () async {
                            await context
                                .read<BillProvider>()
                                .adminMarkMonthPaid(
                                    summary.month, aptId, flat.userId);
                            if (!ctx.mounted) return;
                            AppUtils.showSnackBar(
                              ctx,
                              '${flat.unitNumber} marked as paid!',
                              color: AppColors.paid,
                            );
                          },
                  ),
                );
              },
              childCount: flats.length,
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero Summary Card ───────────────────────────────────────────────────────

  Widget _buildHeroCard(RoleTheme theme, MonthlyBillSummary fresh) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: theme.gradient,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fresh.month,
                      style: AppTextStyles.caption(
                          color: Colors.white.withOpacity(0.8)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppUtils.formatCurrency(fresh.totalAmount),
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Apartment Total Bill',
                      style: AppTextStyles.bodySmall(
                          color: Colors.white.withOpacity(0.85)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.receipt_long_rounded,
                    color: Colors.white, size: 30),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _miniStat(
                    Icons.apartment_outlined, '${fresh.totalFlats}', 'Total Flats'),
                _vertDivider(),
                _miniStat(
                    Icons.account_balance_wallet_outlined,
                    AppUtils.formatCurrency(fresh.perFlatShare),
                    'Per Flat'),
                _vertDivider(),
                _miniStat(
                    Icons.calendar_today_outlined,
                    _shortDate(fresh.dueDate),
                    'Due Date'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String value, String label) => Expanded(
        child: Column(
          children: [
            Icon(icon, color: Colors.white70, size: 15),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontSize: 13),
                textAlign: TextAlign.center),
            Text(label,
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 9,
                    color: Colors.white.withOpacity(0.7)),
                textAlign: TextAlign.center),
          ],
        ),
      );

  Widget _vertDivider() =>
      Container(width: 1, height: 32, color: Colors.white.withOpacity(0.2));

  String _shortDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  // ── Category Breakdown Card ─────────────────────────────────────────────────

  Widget _buildCategoryBreakdown(RoleTheme theme, MonthlyBillSummary fresh, BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.bar_chart_rounded, 'Category Breakdown', cs),
          const SizedBox(height: 12),

          // Column headers
          Padding(
            padding: const EdgeInsets.only(left: 50),
            child: Row(
              children: [
                Expanded(child: const SizedBox()),
                _colLabel('Total', ctx: context),
                const SizedBox(width: 8),
                _colLabel('/Flat', color: theme.effectivePrimary(context), ctx: context),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Bill rows
          ...fresh.bills.map((bill) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_categoryIcon(bill.category),
                          color: theme.primary, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(bill.title,
                              style: AppTextStyles.bodyMedium(
                                      color: cs.onSurface)
                                  .copyWith(fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text(bill.category,
                              style: AppTextStyles.caption(color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    Text(
                      AppUtils.formatCurrency(bill.totalAmount),
                      style: AppTextStyles.bodyMedium(
                              color: cs.onSurface)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 52,
                      child: Text(
                        AppUtils.formatCurrency(bill.perFlatShare),
                        style: AppTextStyles.caption(color: theme.effectivePrimary(context))
                            .copyWith(fontWeight: FontWeight.w600),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              )),

          const Divider(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Apartment Total', style: AppTextStyles.subheading(color: cs.onSurface)),
              Text(AppUtils.formatCurrency(fresh.totalAmount),
                  style: AppTextStyles.subheading(color: theme.effectivePrimary(context))
                      .copyWith(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Per Flat Share', style: AppTextStyles.caption(color: cs.onSurfaceVariant)),
              Text(AppUtils.formatCurrency(fresh.perFlatShare),
                  style: AppTextStyles.caption(color: cs.onSurface)
                      .copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _colLabel(String text, {Color? color, required BuildContext ctx}) => Text(
        text,
        style: AppTextStyles.caption(
            color: color ?? Theme.of(ctx).colorScheme.onSurfaceVariant),
      );

  // ── Collection Progress Card ────────────────────────────────────────────────

  Widget _buildCollectionProgress(
    RoleTheme theme,
    MonthlyBillSummary fresh,
    double collectedAmount,
    double pendingAmount,
    double collectionRate,
    double totalBilledAmount,
    BuildContext context,
  ) {
    final cs = Theme.of(context).colorScheme;
    final isComplete = collectionRate >= 1.0;
    final barColor = isComplete ? AppColors.paid : theme.primary;
    final pendingFlats = fresh.pendingFlats;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.trending_up_rounded, 'Collection Progress', cs),
          const SizedBox(height: 14),

          // Collected / Pending blocks
          Row(
            children: [
              Expanded(
                child: _amountBlock('Collected',
                    AppUtils.formatCurrency(collectedAmount), AppColors.paid,
                    Icons.check_circle_outline),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _amountBlock('Pending',
                    AppUtils.formatCurrency(pendingAmount), AppColors.pending,
                    Icons.schedule_outlined),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Progress bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: collectionRate,
                    backgroundColor: cs.outlineVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    minHeight: 10,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(collectionRate * 100).toInt()}%',
                style: AppTextStyles.label(color: barColor)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${AppUtils.formatCurrency(collectedAmount)} of ${AppUtils.formatCurrency(totalBilledAmount)}',
            style: AppTextStyles.caption(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 14),

          // Stat pills
          Row(
            children: [
              Expanded(
                  child: _statPill('${fresh.fullyPaidFlats}', 'Paid Flats',
                      AppColors.paid, Icons.check_circle_outline)),
              const SizedBox(width: 10),
              Expanded(
                  child: _statPill('$pendingFlats', 'Pending',
                      AppColors.pending, Icons.schedule_outlined)),
              const SizedBox(width: 10),
              Expanded(
                  child: _statPill(AppUtils.formatDate(fresh.dueDate),
                      'Due Date', cs.primary, Icons.calendar_today_outlined,
                      compact: true)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _amountBlock(
      String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.caption(color: color)),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statPill(String value, String label, Color color, IconData icon,
      {bool compact = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: compact ? 9 : 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Builder(builder: (context) => Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 9,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          )),
        ],
      ),
    );
  }

  // ── Shared helpers ──────────────────────────────────────────────────────────

  BoxDecoration _cardDecor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      );
  }

  Widget _sectionHeader(IconData icon, String title, ColorScheme cs) => Row(
        children: [
          Icon(icon, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(title, style: AppTextStyles.subheading(color: cs.onSurface)),
        ],
      );

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Water':      return Icons.water_drop_outlined;
      case 'Lift':       return Icons.elevator_outlined;
      case 'Security':   return Icons.security_outlined;
      case 'Maintenance':return Icons.build_outlined;
      case 'Parking':    return Icons.local_parking_outlined;
      case 'Amenities':  return Icons.fitness_center_outlined;
      default:           return Icons.receipt_outlined;
    }
  }
}

// ── Bill Actions Sheet ────────────────────────────────────────────────────────

void _showDetailBillActions(
  BuildContext context, {
  required BillModel rawBill,
  required MonthlyBillSummary summary,
  required List<UserModel> residents,
  required BillProvider billProvider,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetCtx) {
      final sheetCs = Theme.of(sheetCtx).colorScheme;
      return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: sheetCs.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: sheetCs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  _billActionTile(
                    icon: Icons.edit_outlined,
                    title: 'Edit Bill',
                    subtitle: 'Update categories, amounts or due date',
                    color: Theme.of(sheetCtx).brightness == Brightness.dark
                        ? const Color(0xFF60A5FA)
                        : AppColors.blue,
                    onTap: () {
                      Navigator.pop(context);
                      showEditBillSheet(context,
                          bill: rawBill, residents: residents);
                    },
                  ),
                  const SizedBox(height: 10),
                  _billActionTile(
                    icon: Icons.delete_outline_rounded,
                    title: 'Delete Bill',
                    subtitle: 'Permanently remove bill and all payments',
                    color: AppColors.overdue,
                    isDestructive: true,
                    onTap: () {
                      Navigator.pop(context);
                      _showDeleteBillDialog(
                        context,
                        month: summary.month,
                        billId: rawBill.id,
                        billProvider: billProvider,
                        afterDelete: () => Navigator.pop(context),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      );
    },
  );
}

Widget _billActionTile({
  required IconData icon,
  required String title,
  required String subtitle,
  required Color color,
  required VoidCallback onTap,
  bool isDestructive = false,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Builder(builder: (context) => Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                )),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, color: color, size: 14),
        ],
      ),
    ),
  );
}

void _showDeleteBillDialog(
  BuildContext context, {
  required String month,
  required String billId,
  required BillProvider billProvider,
  VoidCallback? afterDelete,
}) {
  showDialog<bool>(
    context: context,
    builder: (_) => Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.overdue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_rounded,
                  color: AppColors.overdue, size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'Delete Bill?',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'This will permanently delete the $month bill and all payment records. This cannot be undone.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(fontFamily: 'Poppins')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.overdue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Delete',
                        style: TextStyle(
                            fontFamily: 'Poppins', color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  ).then((confirmed) async {
    if (confirmed != true) return;
    if (!context.mounted) return;
    await billProvider.adminDeleteBill(billId);
    if (!context.mounted) return;
    AppUtils.showSnackBar(context, '$month bill deleted');
    afterDelete?.call();
  });
}

// ── Flat Payment Card ─────────────────────────────────────────────────────────

class _FlatPaymentCard extends StatelessWidget {
  final String unitNumber;
  final String? userName;
  final bool isPaid;
  final DateTime? paidDate;
  final double amount;
  final RoleTheme theme;
  final bool isLoading;
  final VoidCallback? onMarkPaid;

  const _FlatPaymentCard({
    required this.unitNumber,
    this.userName,
    required this.isPaid,
    this.paidDate,
    required this.amount,
    required this.theme,
    required this.isLoading,
    this.onMarkPaid,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final adminAccent = theme.effectivePrimary(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: isPaid
            ? Border.all(color: AppColors.paid.withOpacity(0.25))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Unit badge
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: adminAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              unitNumber,
              style: AppTextStyles.label(color: adminAccent)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),

          // Name + share + status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (userName != null)
                  Text(
                    userName!,
                    style: AppTextStyles.bodyMedium(
                            color: cs.onSurface)
                        .copyWith(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                Row(
                  children: [
                    // Per-flat share badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: adminAccent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        AppUtils.formatCurrency(amount),
                        style: AppTextStyles.caption(color: adminAccent)
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: isPaid && paidDate != null
                          ? Text(
                              'Paid ${AppUtils.formatDateTime(paidDate!)}',
                              style: AppTextStyles.caption(
                                  color: AppColors.paid),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : Text(
                              'Pending',
                              style: AppTextStyles.caption(
                                  color: cs.onSurfaceVariant),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Action
          if (isPaid)
            const Icon(Icons.check_circle_rounded,
                color: AppColors.paid, size: 26)
          else
            GestureDetector(
              onTap: isLoading ? null : onMarkPaid,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: theme.gradient),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Mark Paid',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
