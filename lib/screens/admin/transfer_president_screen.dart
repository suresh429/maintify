import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../providers/auth_provider.dart';
import '../../providers/apartment_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/common_button.dart';

class TransferPresidentScreen extends StatefulWidget {
  const TransferPresidentScreen({super.key});

  @override
  State<TransferPresidentScreen> createState() =>
      _TransferPresidentScreenState();
}

class _TransferPresidentScreenState extends State<TransferPresidentScreen> {
  String? _selectedUserId;
  bool _isTransferring = false;

  Future<void> _transfer() async {
    if (_selectedUserId == null) return;

    final auth = context.read<AuthProvider>();
    final aptProvider = context.read<ApartmentProvider>();
    final userProvider = context.read<UserProvider>();

    final currentAdmin = auth.currentUser;
    if (currentAdmin?.apartmentId == null) return;

    final aptId = currentAdmin!.apartmentId!;

    // Guard: make sure selected user isn't already a president elsewhere
    if (aptProvider.isPresidentElsewhere(_selectedUserId!,
        excludingAptId: aptId)) {
      AppUtils.showSnackBar(
          context, 'This resident is already a president elsewhere.',
          isError: true);
      return;
    }

    final selectedUser =
        userProvider.users.firstWhere((u) => u.id == _selectedUserId);

    final confirmed = await AppUtils.showConfirmDialog(
      context,
      title: 'Transfer Presidency',
      message:
          'Transfer presidency to ${selectedUser.name}?\n\nYou will be demoted to resident.',
      confirmText: 'Transfer',
      confirmColor: AppColors.blue,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isTransferring = true);

    if (mounted) {
      await aptProvider.assignPresident(
        aptId,
        _selectedUserId!,
        selectedUser.name,
        oldPresidentId: currentAdmin.id,
      );
    }

    if (!mounted) return;
    setState(() => _isTransferring = false);

    AppUtils.showSnackBar(
        context, 'Presidency transferred successfully!',
        color: AppColors.green);

    // Log out after transfer since this user is no longer admin
    if (mounted) {
      context.read<AuthProvider>().logout();
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final userProvider = context.watch<UserProvider>();
    final aptId = auth.currentUser?.apartmentId ?? '';

    final eligible = userProvider.eligibleForPresident(aptId);

    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Transfer Presidency',
            style: AppTextStyles.heading3(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: AppColors.adminGradient,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.pending.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.pending.withOpacity(0.4), width: 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppColors.pending, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Transferring presidency will demote you to a regular resident. You will be logged out immediately after the transfer.',
                      style:
                          AppTextStyles.caption(color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            Text('Select New President', style: AppTextStyles.heading3()),
            const SizedBox(height: 4),
            Text('Choose a resident from your apartment to take over',
                style: AppTextStyles.caption()),
            const SizedBox(height: 12),

            if (eligible.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 32),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.people_outline,
                        size: 40, color: AppColors.textSecondary),
                    const SizedBox(height: 10),
                    Text('No eligible residents',
                        style: AppTextStyles.subheading()),
                    const SizedBox(height: 4),
                    Text('There are no other residents to transfer to.',
                        style: AppTextStyles.caption()),
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
                          ? AppColors.blue.withOpacity(0.07)
                          : AppColors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color:
                            isSelected ? AppColors.blue : Colors.transparent,
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
                                'Unit ${user.unit}',
                                style: AppTextStyles.caption(),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded,
                              color: AppColors.blue, size: 22),
                      ],
                    ),
                  ),
                );
              }),

            const SizedBox(height: 28),

            CommonButton(
              text: 'Transfer Presidency',
              gradient: _selectedUserId != null ? AppColors.adminGradient : null,
              backgroundColor: _selectedUserId != null
                  ? null
                  : AppColors.textSecondary.withOpacity(0.3),
              icon: Icons.swap_horiz_rounded,
              isLoading: _isTransferring,
              onPressed: _selectedUserId != null ? _transfer : null,
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
