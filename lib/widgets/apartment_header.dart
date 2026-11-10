import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/role_theme.dart';
import '../core/utils/app_utils.dart';
import '../models/fund_model.dart';

/// Reusable header card showing the apartment name, president name,
/// and the current user's role chip.
///
/// Optional [fundSummary]: when provided, shows the community fund balance
/// row with a "View Details" link that opens the fund details bottom sheet.
class ApartmentHeader extends StatelessWidget {
  final String apartmentName;
  final String presidentName;
  final UserRole role;
  final FundSummary? fundSummary;

  const ApartmentHeader({
    super.key,
    required this.apartmentName,
    required this.presidentName,
    required this.role,
    this.fundSummary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = RoleTheme.of(role);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = theme.effectivePrimary(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Apartment info row ────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.apartment_outlined, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      apartmentName,
                      style: AppTextStyles.subheading(color: cs.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.person_outline,
                            size: 12, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'President: $presidentName',
                            style: AppTextStyles.caption(
                                color: cs.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _RoleChip(role: role, theme: theme),
            ],
          ),

          // ── Fund balance row (shown only when fundSummary is provided) ─
          if (fundSummary != null) ...[
            const SizedBox(height: 10),
            Divider(
                height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 10),
            Row(
              children: [
                // Wallet icon badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.paid.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.paid.withValues(alpha: 0.25)),
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded,
                      color: AppColors.paid, size: 14),
                ),
                const SizedBox(width: 7),
                // Balance — Flexible so it shrinks when space is tight
                Flexible(
                  child: Text(
                    'Available: ${AppUtils.formatCurrency(fundSummary!.balance)}',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.paid,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                // View Details — fixed width, never shrinks
                GestureDetector(
                  onTap: () => _showFundDetails(context),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Details',
                        style: AppTextStyles.caption(color: accent)
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                      Icon(Icons.chevron_right_rounded, color: accent, size: 15),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showFundDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FundDetailsSheet(
        summary: fundSummary!,
        role: role,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fund Details Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class FundDetailsSheet extends StatelessWidget {
  final FundSummary summary;
  final UserRole role;
  const FundDetailsSheet({super.key, required this.summary, required this.role});

  @override
  Widget build(BuildContext context) {
    final theme = RoleTheme.of(role);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = theme.effectivePrimary(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: const [0.55, 0.85],
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ListView(
          controller: scrollCtrl,
          padding: EdgeInsets.fromLTRB(
              24, 0, 24, 24 + MediaQuery.of(context).viewPadding.bottom),
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.paid.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded,
                      color: AppColors.paid, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Community Fund',
                        style: AppTextStyles.heading3(color: cs.onSurface)),
                    Text('Fund overview',
                        style:
                            AppTextStyles.caption(color: cs.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Balance highlight ─────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.paid.withValues(alpha: 0.15),
                    AppColors.paid.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.paid.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Available Balance',
                      style:
                          AppTextStyles.caption(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Text(
                    AppUtils.formatCurrency(summary.balance),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: AppColors.paid,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${summary.transactionCount} transaction${summary.transactionCount == 1 ? '' : 's'} recorded',
                    style:
                        AppTextStyles.caption(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Stats row ─────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _SheetStatTile(
                    label: 'Total\nCollected',
                    value: AppUtils.formatCurrency(summary.totalCollected),
                    color: AppColors.paid,
                    icon: Icons.trending_up_rounded,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SheetStatTile(
                    label: 'Total\nExpenses',
                    value: AppUtils.formatCurrency(summary.totalExpensed),
                    color: AppColors.overdue,
                    icon: Icons.trending_down_rounded,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Fund health bar ───────────────────────────────────────────
            if (summary.totalCollectedPaise > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Fund Utilization',
                      style:
                          AppTextStyles.subheading(color: cs.onSurface)),
                  Text(
                    '${((summary.totalExpensedPaise / summary.totalCollectedPaise) * 100).clamp(0, 100).toInt()}%',
                    style: AppTextStyles.subheading(color: accent),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (summary.totalExpensedPaise /
                          summary.totalCollectedPaise)
                      .clamp(0.0, 1.0),
                  backgroundColor:
                      AppColors.paid.withValues(alpha: isDark ? 0.2 : 0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.overdue),
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Collected: ${AppUtils.formatCurrency(summary.totalCollected)}',
                    style: AppTextStyles.caption(color: AppColors.paid),
                  ),
                  Text(
                    'Spent: ${AppUtils.formatCurrency(summary.totalExpensed)}',
                    style: AppTextStyles.caption(color: AppColors.overdue),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // ── Last updated ──────────────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.update_rounded,
                      size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    'Last updated: ${AppUtils.formatDate(summary.lastUpdatedAt)}',
                    style:
                        AppTextStyles.caption(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetStatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final bool isDark;
  const _SheetStatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(value,
              style: AppTextStyles.subheading(color: cs.onSurface)
                  .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style: AppTextStyles.caption(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Role chip (private — unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _RoleChip extends StatelessWidget {
  final UserRole role;
  final RoleTheme theme;
  const _RoleChip({required this.role, required this.theme});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = theme.effectivePrimary(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        theme.label,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: accent,
        ),
      ),
    );
  }
}
