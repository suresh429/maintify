import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../models/apartment_model.dart';
import '../../models/user_model.dart';
import '../../providers/apartment_provider.dart';
import '../../widgets/common_button.dart';

class AssignPresidentScreen extends StatefulWidget {
  const AssignPresidentScreen({super.key});

  @override
  State<AssignPresidentScreen> createState() => _AssignPresidentScreenState();
}

class _AssignPresidentScreenState extends State<AssignPresidentScreen> {
  String? _selectedAptId;
  String? _selectedAdminId;
  bool _isAssigning = false;

  Future<void> _assign() async {
    if (_selectedAptId == null || _selectedAdminId == null) {
      AppUtils.showSnackBar(context, 'Please select apartment and president',
          isError: true);
      return;
    }
    setState(() => _isAssigning = true);
    await context
        .read<ApartmentProvider>()
        .assignPresident(_selectedAptId!, _selectedAdminId!);
    if (!mounted) return;
    setState(() => _isAssigning = false);
    AppUtils.showSnackBar(context, 'President assigned successfully!',
        color: AppColors.green);
    setState(() {
      _selectedAptId = null;
      _selectedAdminId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final admins = MockUsers.admins;
    final aptProvider = context.watch<ApartmentProvider>();

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
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
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
                          'Link a president to manage an apartment building',
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
                ? MockUsers.findById(apt.presidentId!)?.name
                : null;
            return GestureDetector(
              onTap: () => setState(() => _selectedAptId = apt.id),
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
                          Text(
                            currentPresident != null
                                ? '${apt.totalFlats} flats · President: $currentPresident'
                                : '${apt.totalFlats} flats · No president assigned',
                            style: AppTextStyles.caption(
                                color: currentPresident != null
                                    ? AppColors.textSecondary
                                    : AppColors.overdue),
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

          const SizedBox(height: 24),
          Text('Select President', style: AppTextStyles.heading3()),
          const SizedBox(height: 4),
          Text('Choose from existing admins/presidents',
              style: AppTextStyles.caption()),
          const SizedBox(height: 12),

          ...admins.map((admin) {
            final isSelected = _selectedAdminId == admin.id;
            final managedApt = admin.apartmentId != null
                ? MockApartments.findById(admin.apartmentId!)?.name
                : null;
            return GestureDetector(
              onTap: () => setState(() => _selectedAdminId = admin.id),
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
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: RoleTheme.of(UserRole.admin).gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          admin.avatarInitials,
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
                          Text(admin.name, style: AppTextStyles.subheading()),
                          Text(
                            managedApt != null
                                ? 'Currently managing: $managedApt'
                                : admin.email,
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

          const SizedBox(height: 28),

          CommonButton(
            text: 'Assign as President',
            gradient: AppColors.superAdminGradient,
            icon: Icons.link_rounded,
            isLoading: _isAssigning,
            onPressed: _assign,
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
