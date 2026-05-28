import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bill_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../models/user_model.dart';
import '../../widgets/pill_filter_bar.dart';
import '../../widgets/shimmer_loading.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  String _search = '';
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final aptId = auth.currentUser?.apartmentId ?? 'apt1';
    final billProvider = context.watch<BillProvider>();
    final residents = MockUsers.all
        .where((u) => u.role == UserRole.user && u.apartmentId == aptId)
        .toList();

    final filtered = residents.where((u) {
      final matchesSearch = _search.isEmpty ||
          u.name.toLowerCase().contains(_search.toLowerCase()) ||
          u.unit.toLowerCase().contains(_search.toLowerCase());
      if (!matchesSearch) return false;
      if (_filter == 'All') return true;

      final views = billProvider.userBillViews(u.id);
      if (_filter == 'Paid') {
        return views.isNotEmpty && views.every((v) => v.payment.isPaid);
      }
      if (_filter == 'Pending') {
        return views.any((v) => v.payment.isPending);
      }
      if (_filter == 'Overdue') {
        return views.any((v) => v.payment.isOverdue);
      }
      return true;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Search residents...',
              hintStyle: AppTextStyles.bodyMedium(),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AppColors.textSecondary),
            ),
          ),
        ),
        // Modern pill filter
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: PillFilterBar(
            options: const ['All', 'Paid', 'Pending', 'Overdue'],
            selected: _filter,
            activeColor: RoleTheme.of(UserRole.admin).primary,
            onChanged: (f) => setState(() => _filter = f),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text('${filtered.length} residents',
              style: AppTextStyles.caption(color: AppColors.textSecondary)),
        ),
        Expanded(
          child: filtered.isEmpty
              ? EmptyState(
                  title: 'No residents found',
                  subtitle: 'Try a different search or filter',
                  icon: Icons.person_search_outlined,
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _UserCard(
                    user: filtered[i],
                    billProvider: billProvider,
                  ),
                ),
        ),
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  final UserModel user;
  final BillProvider billProvider;
  const _UserCard({required this.user, required this.billProvider});

  @override
  Widget build(BuildContext context) {
    final views = billProvider.userBillViews(user.id);
    final paid = views.where((v) => v.payment.isPaid).length;
    final pending = views.where((v) => v.payment.isPending).length;
    final overdue = views.where((v) => v.payment.isOverdue).length;
    final totalDue = billProvider.totalDueForUser(user.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: AppColors.adminGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(user.avatarInitials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                          fontSize: 16,
                        )),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name, style: AppTextStyles.subheading()),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(user.unit,
                                style: AppTextStyles.caption(
                                        color: AppColors.blue)
                                    .copyWith(fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(user.phone,
                                style: AppTextStyles.caption(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (totalDue > 0)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Due',
                          style: AppTextStyles.caption(
                              color: AppColors.overdue)),
                      Text(
                        AppUtils.formatCurrency(totalDue),
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.bold,
                          color: AppColors.overdue,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  )
                else
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.green, size: 24),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.lightGray.withOpacity(0.5),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _BillStat('$paid', 'Paid', AppColors.green),
                _divider(),
                _BillStat('$pending', 'Pending', AppColors.pending),
                _divider(),
                _BillStat('$overdue', 'Overdue', AppColors.overdue),
                _divider(),
                _BillStat('${views.length}', 'Total', AppColors.blue),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 24,
        color: AppColors.lightGray,
      );
}

class _BillStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _BillStat(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: color,
            )),
        Text(label, style: AppTextStyles.caption()),
      ],
    );
  }
}
