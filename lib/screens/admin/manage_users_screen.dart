import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/apartment_provider.dart';
import '../../providers/bill_provider.dart';
import '../../providers/user_provider.dart';
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
    final aptId = auth.currentUser?.apartmentId ?? '';
    final userProvider = context.watch<UserProvider>();
    final billProvider = context.watch<BillProvider>();
    final aptProvider = context.watch<ApartmentProvider>();
    final theme = RoleTheme.of(UserRole.admin);

    final apt = aptProvider.findById(aptId);
    final maxFlats = apt?.totalFlats ?? 10;
    final occupiedCount = userProvider.memberCountForApartment(aptId);
    final isFull = occupiedCount >= maxFlats;

    // All apartment members: admin + residents (not super admin)
    final members = userProvider.users
        .where((u) =>
            u.apartmentId == aptId && u.role != UserRole.superAdmin)
        .toList()
      ..sort((a, b) {
        // President first, then sort by unit number
        if (a.role == UserRole.admin) return -1;
        if (b.role == UserRole.admin) return 1;
        return a.unit.compareTo(b.unit);
      });

    final filtered = members.where((u) {
      final matchesSearch = _search.isEmpty ||
          u.name.toLowerCase().contains(_search.toLowerCase()) ||
          u.unit.toLowerCase().contains(_search.toLowerCase());
      if (!matchesSearch) return false;
      if (_filter == 'All') return true;

      // Billing filters apply to everyone
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
        // Capacity banner
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isFull
                  ? AppColors.overdue.withOpacity(0.07)
                  : AppColors.paid.withOpacity(0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isFull
                    ? AppColors.overdue.withOpacity(0.25)
                    : AppColors.paid.withOpacity(0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isFull
                      ? Icons.block_rounded
                      : Icons.people_outline_rounded,
                  size: 18,
                  color: isFull ? AppColors.overdue : AppColors.paid,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isFull
                        ? 'All flats are occupied ($occupiedCount / $maxFlats)'
                        : '$occupiedCount / $maxFlats Flats Occupied',
                    style: AppTextStyles.bodySmall(
                      color: isFull ? AppColors.overdue : AppColors.paid,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Search members...',
              hintStyle: AppTextStyles.bodyMedium(),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AppColors.textSecondary),
            ),
          ),
        ),

        // Filter pills
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: PillFilterBar(
            options: const ['All', 'Paid', 'Pending', 'Overdue'],
            selected: _filter,
            activeColor: theme.primary,
            onChanged: (f) => setState(() => _filter = f),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text('${filtered.length} member${filtered.length != 1 ? 's' : ''}',
              style: AppTextStyles.caption(color: AppColors.textSecondary)),
        ),

        Expanded(
          child: filtered.isEmpty
              ? EmptyState(
                  title: 'No members found',
                  subtitle: 'Try a different search or filter',
                  icon: Icons.person_search_outlined,
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _MemberCard(
                    user: filtered[i],
                    billProvider: billProvider,
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Member Card ───────────────────────────────────────────────────────────────

class _MemberCard extends StatelessWidget {
  final UserModel user;
  final BillProvider billProvider;
  const _MemberCard({required this.user, required this.billProvider});

  @override
  Widget build(BuildContext context) {
    final views = billProvider.userBillViews(user.id);
    final paid = views.where((v) => v.payment.isPaid).length;
    final pending = views.where((v) => v.payment.isPending).length;
    final overdue = views.where((v) => v.payment.isOverdue).length;
    final totalDue = billProvider.totalDueForUser(user.id);
    final isPresident = user.role == UserRole.admin;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: isPresident
            ? Border.all(
                color: RoleTheme.of(UserRole.admin).primary.withOpacity(0.3),
                width: 1.5)
            : null,
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
                // Avatar
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isPresident
                          ? AppColors.adminGradient
                          : AppColors.userGradient,
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
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
                      Row(
                        children: [
                          Text(user.name, style: AppTextStyles.subheading()),
                          if (isPresident) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: RoleTheme.of(UserRole.admin)
                                    .primary
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('President',
                                  style: AppTextStyles.caption(
                                          color: RoleTheme.of(UserRole.admin)
                                              .primary)
                                      .copyWith(fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (user.unit.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('Flat ${user.unit}',
                                style: AppTextStyles.caption(
                                        color: AppColors.blue)
                                    .copyWith(fontWeight: FontWeight.w600)),
                          ),
                          if (user.phone.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(user.phone,
                                  style: AppTextStyles.caption(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
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
                else if (views.isNotEmpty)
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.paid, size: 24),
              ],
            ),
          ),

          // Bill stats footer
          if (views.isNotEmpty)
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
                  _BillStat('$paid', 'Paid', AppColors.paid),
                  _divider(),
                  _BillStat('$pending', 'Pending', AppColors.pending),
                  _divider(),
                  _BillStat('$overdue', 'Overdue', AppColors.overdue),
                  _divider(),
                  _BillStat('${views.length}', 'Total', AppColors.blue),
                ],
              ),
            )
          else
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.lightGray.withOpacity(0.5),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(14)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text('No billing records yet',
                      style: AppTextStyles.caption()),
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
