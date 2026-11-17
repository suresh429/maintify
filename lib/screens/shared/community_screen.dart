import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../widgets/maintify_banner_ad.dart';
import '../resident/complaints_screen.dart';
import '../resident/directory_screen.dart';
import 'payment_board_screen.dart';

/// Community screen — three tabs: Payment Board, Complaints, Directory.
class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = RoleTheme.of(UserRole.resident);
    final accent = theme.effectivePrimary(context);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: MaintifyBannerAd(),
          ),

          // ── Filled pill TabBar ──────────────────────────────────────────
          Container(
            color: cs.surface,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceVariant
                    : cs.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: cs.onSurfaceVariant,
                labelPadding: EdgeInsets.zero,
                padding: const EdgeInsets.all(3),
                labelStyle: AppTextStyles.caption(color: Colors.white)
                    .copyWith(fontWeight: FontWeight.w600, fontSize: 11),
                unselectedLabelStyle:
                    AppTextStyles.caption(color: cs.onSurfaceVariant)
                        .copyWith(fontSize: 11),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.receipt_long_outlined, size: 16),
                    text: 'Payment Board',
                    iconMargin: EdgeInsets.only(bottom: 2),
                    height: 36,
                  ),
                  Tab(
                    icon: Icon(Icons.chat_bubble_outline_rounded, size: 16),
                    text: 'Complaints',
                    iconMargin: EdgeInsets.only(bottom: 2),
                    height: 36,
                  ),
                  Tab(
                    icon: Icon(Icons.people_outline_rounded, size: 16),
                    text: 'Directory',
                    iconMargin: EdgeInsets.only(bottom: 2),
                    height: 36,
                  ),
                ],
              ),
            ),
          ),

          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.4)),

          // Tab views
          const Expanded(
            child: TabBarView(
              children: [
                PaymentBoardScreen(),
                _CommunityComplaintView(),
                DirectoryScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Wraps ComplaintsScreen inside the community tab.
class _CommunityComplaintView extends StatelessWidget {
  const _CommunityComplaintView();

  @override
  Widget build(BuildContext context) {
    return const ComplaintsScreen();
  }
}
