import 'package:flutter/material.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../widgets/maintify_banner_ad.dart';
import '../resident/complaints_screen.dart';
import '../resident/directory_screen.dart';
import '../resident/community_fund_summary_screen.dart';
import 'payment_board_screen.dart';

/// Community screen — four tabs: Payment Board, Complaints, Directory, Fund.
class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = RoleTheme.of(UserRole.resident);
    final accent = theme.effectivePrimary(context);
    final cs = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: MaintifyBannerAd(),
          ),
          // TabBar
          Container(
            color: cs.surface,
            child: TabBar(
              labelColor: accent,
              unselectedLabelColor: cs.onSurfaceVariant,
              indicatorColor: accent,
              indicatorWeight: 2.5,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelStyle: AppTextStyles.caption(color: accent)
                  .copyWith(fontWeight: FontWeight.w600, fontSize: 11),
              unselectedLabelStyle:
                  AppTextStyles.caption(color: cs.onSurfaceVariant)
                      .copyWith(fontSize: 11),
              dividerColor: cs.outlineVariant.withValues(alpha: 0.4),
              tabs: const [
                Tab(
                  icon: Icon(Icons.receipt_long_outlined, size: 18),
                  text: 'Payment Board',
                  iconMargin: EdgeInsets.only(bottom: 4),
                ),
                Tab(
                  icon: Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  text: 'Complaints',
                  iconMargin: EdgeInsets.only(bottom: 4),
                ),
                Tab(
                  icon: Icon(Icons.people_outline_rounded, size: 18),
                  text: 'Directory',
                  iconMargin: EdgeInsets.only(bottom: 4),
                ),
                Tab(
                  icon: Icon(Icons.account_balance_wallet_outlined, size: 18),
                  text: 'Fund',
                  iconMargin: EdgeInsets.only(bottom: 4),
                ),
              ],
            ),
          ),
          Divider(
              height: 1,
              color: cs.outlineVariant.withValues(alpha: 0.4)),

          // Tab views
          const Expanded(
            child: TabBarView(
              children: [
                PaymentBoardScreen(),
                _CommunityComplaintView(),
                DirectoryScreen(),
                CommunityFundSummaryScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Wraps ComplaintsScreen inside the community tab.
/// ComplaintsScreen manages its own FAB and empty state.
class _CommunityComplaintView extends StatelessWidget {
  const _CommunityComplaintView();

  @override
  Widget build(BuildContext context) {
    return const ComplaintsScreen();
  }
}
