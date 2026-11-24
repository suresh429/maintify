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
import '../../widgets/maintify_banner_ad.dart';
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
    final theme = RoleTheme.of(UserRole.president);

    final apt = aptProvider.findById(aptId);
    final maxFlats = apt?.totalFlats ?? 10;
    final occupiedCount = userProvider.memberCountForApartment(aptId);
    final isFull = occupiedCount >= maxFlats;

    // All apartment members: admin + residents (not super admin)
    final members = userProvider.users
        .where((u) =>
            u.apartmentId == aptId && u.role != UserRole.admin)
        .toList()
      ..sort((a, b) {
        // President first, then sort by unit number
        if (a.role == UserRole.president) return -1;
        if (b.role == UserRole.president) return 1;
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

    final isWeb = MediaQuery.sizeOf(context).width >= 600;

    return Column(
      children: [
        // Capacity banner
        Padding(
          padding: EdgeInsets.fromLTRB(isWeb ? 24.0 : 8.0, 12, isWeb ? 24.0 : 8.0, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isFull
                  ? AppColors.overdue.withValues(alpha: 0.07)
                  : AppColors.paid.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isFull
                    ? AppColors.overdue.withValues(alpha: 0.25)
                    : AppColors.paid.withValues(alpha: 0.25),
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
          padding: EdgeInsets.fromLTRB(isWeb ? 24.0 : 8.0, 10, isWeb ? 24.0 : 8.0, 0),
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
            activeColor: theme.effectivePrimary(context),
            onChanged: (f) => setState(() => _filter = f),
          ),
        ),
        const MaintifyBannerAd(),
        Padding(
          padding: EdgeInsets.fromLTRB(isWeb ? 24.0 : 8.0, 4, isWeb ? 24.0 : 8.0, 8),
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
                  padding: EdgeInsets.fromLTRB(isWeb ? 24.0 : 8.0, 0, isWeb ? 24.0 : 8.0, 100),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final item = _MemberCard(
                      user: filtered[i],
                      billProvider: billProvider,
                    );
                    return isWeb
                        ? Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 960),
                              child: item,
                            ),
                          )
                        : item;
                  },
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

  Future<bool> _showVerifySheet(BuildContext context) async {
    final totalDue = billProvider.totalDueForUser(user.id);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : cs.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: cs.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.overdue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person_remove_outlined,
                          color: AppColors.overdue, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Verify Before Removing',
                              style: AppTextStyles.heading3(color: cs.onSurface)),
                          Text('Confirm this is an unauthorized resident',
                              style: AppTextStyles.caption(color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Resident details
                _VerifyRow(icon: Icons.person_outline_rounded,
                    label: 'Name', value: user.name, cs: cs),
                _VerifyRow(icon: Icons.door_front_door_outlined,
                    label: 'Flat', value: user.unit.isNotEmpty ? 'Flat ${user.unit}' : '—', cs: cs),
                _VerifyRow(icon: Icons.email_outlined,
                    label: 'Email', value: user.email.isNotEmpty ? user.email : '—', cs: cs),
                _VerifyRow(icon: Icons.phone_outlined,
                    label: 'Mobile', value: user.phone.isNotEmpty ? user.phone : '—', cs: cs),

                // Dues warning
                if (totalDue > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.overdue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.overdue.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: AppColors.overdue, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Has ${AppUtils.formatCurrency(totalDue)} unpaid dues — clear bills before removing.',
                            style: AppTextStyles.caption(color: AppColors.overdue),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Cancel',
                            style: AppTextStyles.buttonText(
                                color: cs.onSurface)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: totalDue > 0
                            ? null
                            : () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.overdue,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              AppColors.overdue.withValues(alpha: 0.3),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Remove',
                            style: AppTextStyles.buttonText(
                                color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return result == true;
  }

  Future<void> _doRemove(BuildContext context) async {
    try {
      final auth = context.read<AuthProvider>();
      final aptId = auth.currentUser?.apartmentId ?? '';
      await context.read<UserProvider>().removeUser(
            user.id,
            aptId: aptId,
            isPresident: false,
          );
      if (context.mounted) {
        AppUtils.showSnackBar(context, '${user.name} removed from apartment.',
            color: AppColors.paid);
      }
    } catch (e) {
      if (context.mounted) AppUtils.showSnackBar(context, 'Failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final adminAccent = RoleTheme.of(UserRole.president).effectivePrimary(context);
    final views = billProvider.userBillViews(user.id);
    final paid = views.where((v) => v.payment.isPaid).length;
    final pending = views.where((v) => v.payment.isPending).length;
    final overdue = views.where((v) => v.payment.isOverdue).length;
    final totalDue = billProvider.totalDueForUser(user.id);
    final isPresident = user.role == UserRole.president;

    final card = Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: isPresident
            ? Border.all(
                color: adminAccent.withValues(alpha: 0.35),
                width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
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
                          Text(user.name, style: AppTextStyles.subheading(color: cs.onSurface)),
                          if (isPresident) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: adminAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('President',
                                  style: AppTextStyles.caption(
                                          color: adminAccent)
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
                              color: adminAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('Flat ${user.unit}',
                                style: AppTextStyles.caption(
                                        color: adminAccent)
                                    .copyWith(fontWeight: FontWeight.w600)),
                          ),
                          if (user.phone.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(user.phone,
                                  style: AppTextStyles.caption(color: cs.onSurfaceVariant),
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
                color: cs.surfaceContainerHighest,
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
                  _BillStat('${views.length}', 'Total',
                      Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF60A5FA)
                          : AppColors.blue),
                ],
              ),
            )
          else
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
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
                      style: AppTextStyles.caption(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
        ],
      ),
    );

    // President card — not dismissible
    if (isPresident) return card;

    // Resident card — swipe left to remove
    return Dismissible(
      key: ValueKey(user.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _showVerifySheet(context),
      onDismissed: (_) => _doRemove(context),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.overdue,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_remove_outlined, color: Colors.white, size: 22),
            SizedBox(height: 4),
            Text('Remove',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                )),
          ],
        ),
      ),
      child: card,
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 24,
        color: AppColors.lightGray.withValues(alpha: 0.5),
      );
}

class _VerifyRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ColorScheme cs;
  const _VerifyRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 12),
          Text('$label: ',
              style: AppTextStyles.caption(color: cs.onSurfaceVariant)),
          Expanded(
            child: Text(value,
                style: AppTextStyles.bodySmall(color: cs.onSurface)
                    .copyWith(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
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
        Text(label, style: AppTextStyles.caption(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
