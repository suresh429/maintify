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
import '../../widgets/app_text_field.dart';
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

  void _showAddMemberSheet(String aptId, int maxFlats) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddMemberSheet(aptId: aptId, maxFlats: maxFlats),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final aptId = auth.currentUser?.apartmentId ?? 'apt1';
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

        // Search bar + Add button row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            children: [
              Expanded(
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
              if (!isFull) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => _showAddMemberSheet(aptId, maxFlats),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: theme.gradient,
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: theme.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_add_rounded,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 6),
                        Text('Add',
                            style: AppTextStyles.buttonText(
                                    color: Colors.white)
                                .copyWith(fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
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

// ── Add Member Bottom Sheet ───────────────────────────────────────────────────

class _AddMemberSheet extends StatefulWidget {
  final String aptId;
  final int maxFlats;
  const _AddMemberSheet({required this.aptId, required this.maxFlats});

  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  final _flatCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  @override
  void dispose() {
    _flatCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final password = context.read<UserProvider>().addMember(
            flatNumber: _flatCtrl.text.trim(),
            name: _nameCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            aptId: widget.aptId,
            maxFlats: widget.maxFlats,
          );
      if (!mounted) return;
      // Show credentials before closing sheet
      await AppUtils.showGeneratedCredentials(
        context,
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: password,
        role: 'Resident',
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      setState(() => _isSaving = false);
      AppUtils.showSnackBar(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = RoleTheme.of(UserRole.admin);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.lightGray,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: theme.gradient,
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.person_add_rounded,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Add Member',
                              style: AppTextStyles.subheading()),
                          Text(
                              '${widget.maxFlats - context.read<UserProvider>().memberCountForApartment(widget.aptId)} slot(s) remaining',
                              style: AppTextStyles.caption()),
                        ],
                      ),
                    ],
                  ),
                ),

                // Flat Number field
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: AppTextField(
                    label: 'Flat Number',
                    hint: 'e.g., 103, 203, 601',
                    controller: _flatCtrl,
                    textCapitalization: TextCapitalization.characters,
                    focusColor: theme.primary,
                    prefixIcon: const Icon(Icons.door_front_door_outlined),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Flat number is required';
                      }
                      return null;
                    },
                  ),
                ),

                // Name field
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: AppTextField(
                    label: 'Resident Name',
                    hint: 'e.g., Kiran, Meena Rao',
                    controller: _nameCtrl,
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                    focusColor: theme.primary,
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Name is required';
                      }
                      if (v.trim().length < 2) {
                        return 'Name must be at least 2 characters';
                      }
                      return null;
                    },
                  ),
                ),

                // Email field
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: AppTextField(
                    label: 'Login Email',
                    hint: 'e.g., kiran@apartment.com',
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    focusColor: theme.primary,
                    prefixIcon: const Icon(Icons.email_outlined),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Email is required';
                      }
                      if (!v.contains('@') || !v.contains('.')) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                ),

                // Auto-password notice
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.paid.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.paid.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded,
                            size: 16, color: AppColors.paid),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Password will be auto-generated and shown after adding.',
                            style: AppTextStyles.caption(
                                color: AppColors.paid),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Action buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              _isSaving ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color: AppColors.textSecondary
                                    .withOpacity(0.4)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text('Cancel',
                              style: AppTextStyles.buttonText(
                                  color: AppColors.textSecondary)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _isSaving
                            ? Container(
                                height: 50,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: theme.gradient,
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2.5),
                                  ),
                                ),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: theme.gradient,
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.primary.withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: _save,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                              Icons.person_add_rounded,
                                              color: Colors.white,
                                              size: 18),
                                          const SizedBox(width: 8),
                                          Text('Add Member',
                                              style: AppTextStyles.buttonText(
                                                  color: Colors.white)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
