import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../models/apartment_model.dart';
import '../../models/user_model.dart';
import '../../providers/apartment_provider.dart';
import '../../providers/bill_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/app_text_field.dart';
import 'create_apartment_screen.dart';

class ApartmentsScreen extends StatefulWidget {
  const ApartmentsScreen({super.key});

  @override
  State<ApartmentsScreen> createState() => _ApartmentsScreenState();
}

class _ApartmentsScreenState extends State<ApartmentsScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final aptProvider = context.watch<ApartmentProvider>();
    final superAccent = RoleTheme.of(UserRole.admin).effectivePrimary(context);
    final adminAccent = RoleTheme.of(UserRole.president).effectivePrimary(context);
    final filtered = aptProvider.apartments
        .where((a) =>
            a.name.toLowerCase().contains(_search.toLowerCase()) ||
            a.code.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    final isWeb = MediaQuery.sizeOf(context).width >= 600;
    final hPad = isWeb ? 24.0 : 16.0;
    final maxW = isWeb ? 1100.0 : double.infinity;

    return Column(
      children: [
        // ── Search + summary header ─────────────────────────────────────
        Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: Padding(
              padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 0),
              child: Column(
                children: [
                  TextField(
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      hintText: 'Search apartments...',
                      hintStyle: AppTextStyles.bodyMedium(),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppColors.textSecondary),
                      suffixIcon: _search.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setState(() => _search = ''),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _SummaryChip(
                        label: '${aptProvider.apartments.length} Properties',
                        color: superAccent,
                        icon: Icons.apartment_outlined,
                      ),
                      const SizedBox(width: 10),
                      _SummaryChip(
                        label:
                            '${aptProvider.apartments.fold(0, (s, a) => s + a.totalFlats)} Total Flats',
                        color: adminAccent,
                        icon: Icons.door_front_door_outlined,
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const CreateApartmentScreen()),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: AppColors.superAdminGradient,
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Add',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),

        // ── Apartment list ──────────────────────────────────────────────
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                itemCount: filtered.length,
                itemBuilder: (_, i) => _ApartmentDetailCard(apt: filtered[i]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Summary chip ──────────────────────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _SummaryChip(
      {required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              )),
        ],
      ),
    );
  }
}

// ── Apartment detail card ─────────────────────────────────────────────────────

class _ApartmentDetailCard extends StatelessWidget {
  final ApartmentModel apt;
  const _ApartmentDetailCard({required this.apt});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = RoleTheme.of(UserRole.admin).effectivePrimary(context);
    final adminAccent = RoleTheme.of(UserRole.president).effectivePrimary(context);
    final billProvider = context.watch<BillProvider>();
    final presidentName = apt.presidentName ?? 'Unassigned';
    final collected = billProvider.collectedForApartment(apt.id);
    final pending = billProvider.pendingForApartment(apt.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.08),
                  AppColors.blue.withValues(alpha: 0.04),
                ],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.apartment_rounded,
                      color: accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(apt.name,
                          style: AppTextStyles.subheading(color: cs.onSurface)),
                      Text(apt.code,
                          style: AppTextStyles.caption(
                              color: cs.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                // Status chip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: apt.hasPresident
                        ? AppColors.green.withValues(alpha: 0.1)
                        : AppColors.overdue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    apt.hasPresident ? 'Active' : 'No President',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: apt.hasPresident
                          ? AppColors.green
                          : AppColors.overdue,
                    ),
                  ),
                ),
                // 3-dot actions menu
                PopupMenuButton<_AptAction>(
                  icon: Icon(Icons.more_vert,
                      color: cs.onSurfaceVariant, size: 20),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onSelected: (action) {
                    switch (action) {
                      case _AptAction.edit:
                        _showEditSheet(context, apt);
                      case _AptAction.members:
                        _showMembersSheet(context, apt);
                      case _AptAction.delete:
                        _confirmDelete(context, apt);
                    }
                  },
                  itemBuilder: (_) => [
                    _menuItem(
                      value: _AptAction.edit,
                      icon: Icons.edit_outlined,
                      label: 'Edit Apartment',
                      color: cs.onSurface,
                    ),
                    _menuItem(
                      value: _AptAction.members,
                      icon: Icons.people_outline_rounded,
                      label: 'Manage Members',
                      color: cs.onSurface,
                    ),
                    _menuItem(
                      value: _AptAction.delete,
                      icon: Icons.delete_outline_rounded,
                      label: 'Delete Apartment',
                      color: AppColors.overdue,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _InfoTile(
                        icon: Icons.door_front_door_outlined,
                        label: 'Total Flats',
                        value: '${apt.totalFlats}',
                        color: adminAccent,
                      ),
                    ),
                    Container(
                        width: 1, height: 36, color: cs.outlineVariant),
                    Expanded(
                      child: _InfoTile(
                        icon: Icons.person_outline,
                        label: 'President',
                        value: presidentName,
                        color: apt.hasPresident
                            ? cs.onSurface
                            : AppColors.overdue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _FinanceTile(
                        label: 'Collected',
                        value: AppUtils.formatCurrency(collected),
                        color: AppColors.green,
                      ),
                    ),
                    Container(
                        width: 1, height: 36, color: cs.outlineVariant),
                    Expanded(
                      child: _FinanceTile(
                        label: 'Pending',
                        value: AppUtils.formatCurrency(pending),
                        color: AppColors.pending,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<_AptAction> _menuItem({
    required _AptAction value,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Edit apartment ──────────────────────────────────────────────────────────

  void _showEditSheet(BuildContext context, ApartmentModel apt) {
    final nameCtrl = TextEditingController(text: apt.name);
    final addrCtrl = TextEditingController(text: apt.address ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          child: _EditApartmentSheet(
            nameCtrl: nameCtrl,
            addrCtrl: addrCtrl,
            apt: apt,
          ),
        ),
      ),
    );
  }

  // ── Manage members ──────────────────────────────────────────────────────────

  void _showMembersSheet(BuildContext context, ApartmentModel apt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MembersSheet(apt: apt),
    );
  }

  // ── Delete apartment ────────────────────────────────────────────────────────

  Future<void> _confirmDelete(BuildContext context, ApartmentModel apt) async {
    final confirmed = await AppUtils.showConfirmDialog(
      context,
      title: 'Delete Apartment',
      message:
          'This will permanently delete "${apt.name}" along with all members, bills, payments, complaints, and meetings. Member accounts will also be deleted from Firebase. This cannot be undone.',
      confirmText: 'Delete',
      confirmColor: AppColors.overdue,
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await context.read<ApartmentProvider>().deleteApartment(apt.id);
      if (context.mounted) {
        AppUtils.showSnackBar(context, 'Apartment deleted',
            color: AppColors.paid);
      }
    } catch (e) {
      if (context.mounted) {
        AppUtils.showSnackBar(context, 'Delete failed: $e',
            color: AppColors.overdue);
      }
    }
  }
}

enum _AptAction { edit, members, delete }

// ── Edit apartment bottom sheet ───────────────────────────────────────────────

class _EditApartmentSheet extends StatefulWidget {
  final TextEditingController nameCtrl;
  final TextEditingController addrCtrl;
  final ApartmentModel apt;

  const _EditApartmentSheet({
    required this.nameCtrl,
    required this.addrCtrl,
    required this.apt,
  });

  @override
  State<_EditApartmentSheet> createState() => _EditApartmentSheetState();
}

class _EditApartmentSheetState extends State<_EditApartmentSheet> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = RoleTheme.of(UserRole.admin).effectivePrimary(context);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Edit Apartment',
              style: AppTextStyles.heading3(color: cs.onSurface)),
          const SizedBox(height: 4),
          Text('Code: ${widget.apt.code}',
              style: AppTextStyles.caption(color: cs.onSurfaceVariant)),
          const SizedBox(height: 24),
          AppTextField(
            controller: widget.nameCtrl,
            label: 'Apartment Name',
            focusColor: accent,
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: widget.addrCtrl,
            label: 'Address',
            focusColor: accent,
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text('Save Changes',
                      style: AppTextStyles.buttonText()),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = widget.nameCtrl.text.trim();
    if (name.isEmpty) {
      AppUtils.showSnackBar(context, 'Apartment name cannot be empty',
          color: AppColors.overdue);
      return;
    }
    setState(() => _loading = true);
    try {
      await context.read<ApartmentProvider>().editApartment(
            widget.apt.id,
            name: name,
            address: widget.addrCtrl.text.trim(),
          );
      if (mounted) {
        Navigator.pop(context);
        AppUtils.showSnackBar(context, 'Apartment updated',
            color: AppColors.paid);
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showSnackBar(context, 'Update failed: $e',
            color: AppColors.overdue);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ── Manage members bottom sheet ───────────────────────────────────────────────

class _MembersSheet extends StatelessWidget {
  final ApartmentModel apt;
  const _MembersSheet({required this.apt});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final userProv = context.watch<UserProvider>();
    final members = userProv.membersForApartment(apt.id);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Members — ${apt.name}',
              style: AppTextStyles.heading3(color: cs.onSurface)),
          Text('${members.length} member(s)',
              style: AppTextStyles.caption(color: cs.onSurfaceVariant)),
          const SizedBox(height: 16),
          if (members.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No members yet.',
                    style: AppTextStyles.bodySmall(
                        color: cs.onSurfaceVariant)),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: members.length,
                separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: cs.outlineVariant.withValues(alpha: 0.4)),
                itemBuilder: (_, i) =>
                    _MemberTile(member: members[i], apt: apt),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Member tile with Edit / Remove ────────────────────────────────────────────

class _MemberTile extends StatelessWidget {
  final UserModel member;
  final ApartmentModel apt;
  const _MemberTile({required this.member, required this.apt});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPresident = member.role == UserRole.president;
    final roleColor =
        isPresident ? const Color(0xFF3B82F6) : cs.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: roleColor.withValues(alpha: 0.12),
            child: Text(
              member.avatarInitials,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: roleColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: AppTextStyles.bodySmall(color: cs.onSurface)
                      .copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${isPresident ? "President" : "Resident"} · Flat ${member.unit}',
                  style: AppTextStyles.caption(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          // Edit button
          IconButton(
            icon: Icon(Icons.edit_outlined,
                size: 18, color: cs.onSurfaceVariant),
            tooltip: 'Edit',
            onPressed: () => _showEditUserSheet(context, member),
          ),
          // Remove button
          IconButton(
            icon: const Icon(Icons.person_remove_outlined,
                size: 18, color: AppColors.overdue),
            tooltip: 'Remove',
            onPressed: () => _confirmRemove(context, member, isPresident),
          ),
        ],
      ),
    );
  }

  void _showEditUserSheet(BuildContext context, UserModel user) {
    final nameCtrl = TextEditingController(text: user.name);
    final phoneCtrl = TextEditingController(text: user.phone);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          child: _EditUserSheet(
              user: user, nameCtrl: nameCtrl, phoneCtrl: phoneCtrl),
        ),
      ),
    );
  }

  Future<void> _confirmRemove(
      BuildContext context, UserModel user, bool isPresident) async {
    final confirmed = await AppUtils.showConfirmDialog(
      context,
      title: 'Remove Member',
      message:
          'Remove "${user.name}" from ${apt.name}? Their account will be deactivated.',
      confirmText: 'Remove',
      confirmColor: AppColors.overdue,
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await context.read<UserProvider>().removeUser(
            user.id,
            aptId: apt.id,
            isPresident: isPresident,
          );
      if (context.mounted) {
        AppUtils.showSnackBar(context, '${user.name} removed',
            color: AppColors.paid);
      }
    } catch (e) {
      if (context.mounted) {
        AppUtils.showSnackBar(context, 'Remove failed: $e',
            color: AppColors.overdue);
      }
    }
  }
}

// ── Edit user bottom sheet ────────────────────────────────────────────────────

class _EditUserSheet extends StatefulWidget {
  final UserModel user;
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;

  const _EditUserSheet({
    required this.user,
    required this.nameCtrl,
    required this.phoneCtrl,
  });

  @override
  State<_EditUserSheet> createState() => _EditUserSheetState();
}

class _EditUserSheetState extends State<_EditUserSheet> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = RoleTheme.of(UserRole.admin).effectivePrimary(context);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Edit Member',
              style: AppTextStyles.heading3(color: cs.onSurface)),
          Text(widget.user.email,
              style: AppTextStyles.caption(color: cs.onSurfaceVariant)),
          const SizedBox(height: 24),
          AppTextField(
            controller: widget.nameCtrl,
            label: 'Full Name',
            focusColor: accent,
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: widget.phoneCtrl,
            label: 'Phone Number',
            keyboardType: TextInputType.phone,
            focusColor: accent,
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text('Save Changes',
                      style: AppTextStyles.buttonText()),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = widget.nameCtrl.text.trim();
    if (name.isEmpty) {
      AppUtils.showSnackBar(context, 'Name cannot be empty',
          color: AppColors.overdue);
      return;
    }
    setState(() => _loading = true);
    try {
      await context.read<UserProvider>().editUser(
            widget.user.id,
            name: name,
            phone: widget.phoneCtrl.text.trim(),
          );
      if (mounted) {
        Navigator.pop(context);
        AppUtils.showSnackBar(context, 'Member updated',
            color: AppColors.paid);
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showSnackBar(context, 'Update failed: $e',
            color: AppColors.overdue);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ── Supporting tiles ──────────────────────────────────────────────────────────

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _InfoTile(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(label,
                  style: AppTextStyles.caption(
                      color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _FinanceTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _FinanceTile(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              )),
          const SizedBox(height: 2),
          Text(label,
              style: AppTextStyles.caption(
                  color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
