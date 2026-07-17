import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bill_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../widgets/shimmer_loading.dart';
import 'monthly_bill_detail_screen.dart';

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  String _filter = 'All';
  static const _filters = ['All', 'Pending', 'Paid'];

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final userId = auth.currentUser?.id ?? '';
    final aptId = auth.currentUser?.apartmentId ?? '';
    final billProvider = context.watch<BillProvider>();
    final theme = RoleTheme.of(UserRole.user);

    if (billProvider.isInitialLoading || billProvider.isLoading) return const ShimmerDashboard();

    final allSummaries = billProvider.userMonthlySummaries(userId);
    final displayed = _filter == 'Pending'
        ? allSummaries.where((s) => !s.isFullyPaid).toList()
        : _filter == 'Paid'
            ? allSummaries.where((s) => s.isFullyPaid).toList()
            : allSummaries;

    return Column(
      children: [
        // Filter tabs
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: _filters.map((f) {
              final isActive = _filter == f;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _filter = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: isActive
                          ? LinearGradient(colors: theme.gradient)
                          : null,
                      color: isActive ? null : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Text(
                      f,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${displayed.length} month${displayed.length != 1 ? 's' : ''}',
              style: AppTextStyles.caption(),
            ),
          ),
        ),
        const SizedBox(height: 4),

        Expanded(
          child: displayed.isEmpty
              ? EmptyState(
                  title: _filter == 'Pending'
                      ? 'No pending bills'
                      : _filter == 'Paid'
                          ? 'No paid months yet'
                          : 'No bills',
                  subtitle: _filter == 'Pending'
                      ? "You're all caught up!"
                      : 'Bills will appear here',
                  icon: _filter == 'Pending'
                      ? Icons.check_circle_outline
                      : Icons.receipt_outlined,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: displayed.length,
                  itemBuilder: (_, i) => _UserMonthlyCard(
                    summary: displayed.elementAt(i),
                    aptId: aptId,
                    theme: theme,
                  ),
                ),
        ),
      ],
    );
  }
}

class _UserMonthlyCard extends StatelessWidget {
  final UserMonthlySummary summary;
  final String aptId;
  final RoleTheme theme;

  const _UserMonthlyCard({
    required this.summary,
    required this.aptId,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (summary.status) {
      case 'Paid':
        statusColor = AppColors.paid;
        statusLabel = 'Paid';
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'Partial':
        statusColor = AppColors.pending;
        statusLabel = 'Partial';
        statusIcon = Icons.timelapse_rounded;
        break;
      case 'Overdue':
        statusColor = AppColors.overdue;
        statusLabel = 'Overdue';
        statusIcon = Icons.error_rounded;
        break;
      default:
        statusColor = AppColors.overdue;
        statusLabel = 'Pending';
        statusIcon = Icons.schedule_rounded;
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserMonthlyBillDetailScreen(
            summary: summary,
            aptId: aptId,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: summary.status != 'Paid'
              ? Border.all(color: statusColor.withOpacity(0.2))
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(statusIcon, color: statusColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(summary.month, style: AppTextStyles.subheading(color: cs.onSurface)),
                  const SizedBox(height: 3),
                  Text(
                    '${summary.views.length} categor${summary.views.length == 1 ? 'y' : 'ies'} · ${AppUtils.formatCurrency(summary.totalAmount)}',
                    style: AppTextStyles.caption(color: cs.onSurfaceVariant),
                  ),
                  if (summary.isFullyPaid && summary.paidDate != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Paid on ${AppUtils.formatDateTime(summary.paidDate!)}',
                      style: AppTextStyles.caption(color: AppColors.paid),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ] else ...[
                    const SizedBox(height: 3),
                    Text(
                      'Due: ${AppUtils.formatDate(summary.dueDate)}',
                      style: AppTextStyles.caption(color: summary.status == 'Overdue'
                          ? AppColors.overdue
                          : AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondary, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
