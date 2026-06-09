import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../models/user_model.dart';
import '../../providers/apartment_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/common_button.dart';

class AssignPresidentScreen extends StatefulWidget {
  const AssignPresidentScreen({super.key});

  @override
  State<AssignPresidentScreen> createState() => _AssignPresidentScreenState();
}

class _AssignPresidentScreenState extends State<AssignPresidentScreen> {
  String? _selectedAptId;
  String? _selectedUserId;
  bool _isAssigning = false;

  Future<void> _assign() async {
    if (_selectedAptId == null || _selectedUserId == null) return;

    final aptProvider = context.read<ApartmentProvider>();
    final userProvider = context.read<UserProvider>();

    // Guard: provider-level check before mutating
    if (aptProvider.isPresidentElsewhere(_selectedUserId!,
        excludingAptId: _selectedAptId)) {
      AppUtils.showSnackBar(
          context, 'This user is already a president of another apartment.',
          isError: true);
      return;
    }

    final oldPresidentId = aptProvider.currentPresidentId(_selectedAptId!);
    final isTransfer = oldPresidentId != null;

    final confirmed = await AppUtils.showConfirmDialog(
      context,
      title: isTransfer ? 'Transfer Presidency' : 'Assign President',
      message: isTransfer
          ? 'The current president will be demoted to resident. Continue?'
          : 'Assign this resident as the apartment president?',
      confirmText: isTransfer ? 'Transfer' : 'Assign',
      confirmColor: AppColors.blue,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isAssigning = true);

    final selectedUser = userProvider.findById(_selectedUserId!);
    if (selectedUser == null || !mounted) {
      setState(() => _isAssigning = false);
      return;
    }

    await context.read<ApartmentProvider>().assignPresident(
          _selectedAptId!,
          _selectedUserId!,
          selectedUser.name,
          oldPresidentId: oldPresidentId,
        );

    if (!mounted) return;
    setState(() {
      _isAssigning = false;
      _selectedAptId = null;
      _selectedUserId = null;
    });

    AppUtils.showSnackBar(
        context,
        isTransfer
            ? 'Presidency transferred successfully!'
            : 'President assigned successfully!',
        color: AppColors.green);
  }

  @override
  Widget build(BuildContext context) {
    final aptProvider = context.watch<ApartmentProvider>();
    final userProvider = context.watch<UserProvider>();

    final eligible = _selectedAptId != null
        ? userProvider.eligibleForPresident(_selectedAptId!)
        : <UserModel>[];

    final isTransfer = _selectedAptId != null &&
        aptProvider.currentPresidentId(_selectedAptId!) != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppColors.superAdminGradient,
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.manage_accounts_outlined,
                    color: Colors.white, size: 32),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Assign President',
                          style:
                              AppTextStyles.subheading(color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(
                          'Select an apartment and choose an eligible resident',
                          style: AppTextStyles.caption(
                              color: Colors.white.withOpacity(0.8))),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Text('Select Apartment', style: AppTextStyles.heading3()),
          const SizedBox(height: 12),

          ...aptProvider.apartments.map((apt) {
            final isSelected = _selectedAptId == apt.id;
            final currentPresident = apt.hasPresident
                ? userProvider.findById(apt.presidentId!)?.name
                : null;
            final hasPresident = currentPresident != null;

            return GestureDetector(
              onTap: () => setState(() {
                _selectedAptId = apt.id;
                _selectedUserId = null; // reset user when apartment changes
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.purple.withOpacity(0.08)
                      : AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color:
                        isSelected ? AppColors.purple : Colors.transparent,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.purple.withOpacity(0.12)
                            : AppColors.lightGray,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.apartment_outlined,
                          color: isSelected
                              ? AppColors.purple
                              : AppColors.textSecondary,
                          size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(apt.name, style: AppTextStyles.subheading()),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: hasPresident
                                      ? AppColors.green
                                      : AppColors.overdue,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  hasPresident
                                      ? 'President: $currentPresident'
                                      : 'No president assigned',
                                  style: AppTextStyles.caption(
                                      color: hasPresident
                                          ? AppColors.textSecondary
                                          : AppColors.overdue),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${apt.totalFlats} flats · ${apt.city}',
                            style: AppTextStyles.caption(),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.purple, size: 22),
                  ],
                ),
              ),
            );
          }),

          if (_selectedAptId != null) ...[
            const SizedBox(height: 24),
            Text(
              isTransfer ? 'Select New President' : 'Select President',
              style: AppTextStyles.heading3(),
            ),
            const SizedBox(height: 4),
            Text(
              'Only residents of this apartment who are not already a president elsewhere',
              style: AppTextStyles.caption(),
            ),
            const SizedBox(height: 12),

            if (eligible.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.people_outline,
                        size: 36, color: AppColors.textSecondary),
                    const SizedBox(height: 8),
                    Text('No eligible residents',
                        style: AppTextStyles.subheading()),
                    const SizedBox(height: 4),
                    Text(
                        'All residents of this apartment are already serving as presidents elsewhere, or there are no residents yet.',
                        style: AppTextStyles.caption(),
                        textAlign: TextAlign.center),
                  ],
                ),
              )
            else
              ...eligible.map((user) {
                final isSelected = _selectedUserId == user.id;
                return GestureDetector(
                  onTap: () => setState(() => _selectedUserId = user.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.purple.withOpacity(0.08)
                          : AppColors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.purple
                            : Colors.transparent,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: RoleTheme.of(UserRole.user).gradient,
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              user.avatarInitials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Poppins',
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.name,
                                  style: AppTextStyles.subheading()),
                              Text(
                                'Unit ${user.unit} · ${user.email}',
                                style: AppTextStyles.caption(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded,
                              color: AppColors.purple, size: 22),
                      ],
                    ),
                  ),
                );
              }),
          ],

          const SizedBox(height: 28),

          CommonButton(
            text: isTransfer ? 'Transfer Presidency' : 'Assign as President',
            gradient: _selectedAptId != null && _selectedUserId != null
                ? AppColors.superAdminGradient
                : null,
            backgroundColor: _selectedAptId != null && _selectedUserId != null
                ? null
                : AppColors.textSecondary.withOpacity(0.3),
            icon: isTransfer ? Icons.swap_horiz_rounded : Icons.link_rounded,
            isLoading: _isAssigning,
            onPressed: _selectedAptId != null && _selectedUserId != null
                ? _assign
                : null,
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
