import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/maintify_banner_ad.dart';
import '../resident/complaints_screen.dart';
import '../resident/directory_screen.dart';
import 'payment_board_screen.dart';

/// Community screen — three tabs: Payment Board, Complaints, Directory.
class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 3,
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
              labelColor: AppColors.green,
              unselectedLabelColor: cs.onSurfaceVariant,
              indicatorColor: AppColors.green,
              indicatorWeight: 1,
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: AppTextStyles.caption(color: AppColors.green)
                  .copyWith(fontWeight: FontWeight.w700, fontSize: 11),
              unselectedLabelStyle:
                  AppTextStyles.caption(color: cs.onSurfaceVariant)
                      .copyWith(fontSize: 11),
              dividerColor: cs.outlineVariant.withValues(alpha: 0.4),
              tabs: const [
                Tab(
                  icon: Icon(Icons.receipt_long_outlined, size: 16),
                  text: 'Payment Board',
                  iconMargin: EdgeInsets.only(bottom: 2),
                  height: 46,
                ),
                Tab(
                  icon: Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  text: 'Complaints',
                  iconMargin: EdgeInsets.only(bottom: 2),
                  height: 46,
                ),
                Tab(
                  icon: Icon(Icons.people_outline_rounded, size: 16),
                  text: 'Directory',
                  iconMargin: EdgeInsets.only(bottom: 2),
                  height: 46,
                ),
              ],
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
