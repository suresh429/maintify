import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/role_theme.dart';
import '../core/utils/app_utils.dart';
import '../models/fund_model.dart';
import '../screens/president/community_fund_screen.dart';

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
            GestureDetector(
              onTap: () => _showFundDetails(context),
              behavior: HitTestBehavior.opaque,
              child: Row(
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
                  const SizedBox(width: 8),
                  // Label
                  Text(
                    'Available Balance',
                    style: AppTextStyles.caption(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(width: 6),
                  // Amount — Flexible so it shrinks when space is tight
                  Expanded(
                    child: Text(
                      AppUtils.formatCurrency(fundSummary!.balance),
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.paid,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Chevron at the far right
                  Icon(Icons.chevron_right_rounded,
                      color: cs.onSurfaceVariant, size: 18),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showFundDetails(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommunityFundScreen(role: role),
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
