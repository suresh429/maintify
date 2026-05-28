import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bill_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../widgets/bill_card.dart';
import '../../widgets/pill_filter_bar.dart';
import '../../widgets/shimmer_loading.dart';

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  String _filter = 'Pending';
  String _search = '';

  static const _filters = ['Pending', 'Paid', 'All'];

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final userId = auth.currentUser?.id ?? 'u3';
    final billProvider = context.watch<BillProvider>();
    final theme = RoleTheme.of(UserRole.user);

    final allViews = billProvider.userBillViews(userId);
    final pendingViews = allViews.where((v) => !v.payment.isPaid).toList();
    final paidViews = allViews.where((v) => v.payment.isPaid).toList();

    List<UserBillView> _baseList() {
      switch (_filter) {
        case 'Pending':
          return pendingViews;
        case 'Paid':
          return paidViews;
        default:
          return allViews;
      }
    }

    final baseList = _baseList();
    final displayed = _search.isEmpty
        ? baseList
        : baseList
            .where((v) =>
                v.bill.title.toLowerCase().contains(_search.toLowerCase()) ||
                v.bill.category.toLowerCase().contains(_search.toLowerCase()))
            .toList();

    final counts = {
      'Pending': pendingViews.length,
      'Paid': paidViews.length,
      'All': allViews.length,
    };

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Search bills...',
              hintStyle: AppTextStyles.bodyMedium(),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AppColors.textSecondary),
            ),
          ),
        ),

        // Pill filter
        PillFilterBar(
          options: _filters
              .map((f) => '$f (${counts[f]})')
              .toList(),
          selected: '$_filter (${counts[_filter]})',
          activeColor: theme.primary,
          onChanged: (val) {
            // Extract the filter name before the count
            setState(() => _filter = val.split(' (').first);
          },
        ),

        const SizedBox(height: 12),

        // Count label
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                '${displayed.length} bill${displayed.length != 1 ? 's' : ''}',
                style: AppTextStyles.caption(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // List
        Expanded(
          child: displayed.isEmpty
              ? EmptyState(
                  title: _filter == 'Pending'
                      ? 'No pending bills'
                      : _filter == 'Paid'
                          ? 'No paid bills yet'
                          : 'No bills',
                  subtitle: _filter == 'Pending'
                      ? "You're all caught up!"
                      : 'Bills will appear here',
                  icon: _filter == 'Pending'
                      ? Icons.check_circle_outline
                      : Icons.receipt_outlined,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: displayed.length,
                  itemBuilder: (_, i) => BillCard(view: displayed[i]),
                ),
        ),
      ],
    );
  }
}
