import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../models/security_staff_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/security_staff_provider.dart';
import '../../widgets/shimmer_loading.dart';
import 'add_edit_security_staff_screen.dart';

class SecurityStaffManagementScreen extends StatelessWidget {
  const SecurityStaffManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = RoleTheme.of(UserRole.president);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text('Watchman & Security',
            style: AppTextStyles.heading3(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: theme.gradient,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
      ),
      floatingActionButton: _AddStaffFAB(theme: theme),
      body: const _SecurityStaffList(),
    );
  }
}

// ── FAB ───────────────────────────────────────────────────────────────────────

class _AddStaffFAB extends StatelessWidget {
  final RoleTheme theme;
  const _AddStaffFAB({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: theme.gradient,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.primary.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddEditSecurityStaffScreen(),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_add_rounded,
                    color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Add Staff',
                    style: AppTextStyles.buttonText(color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Staff list ────────────────────────────────────────────────────────────────

class _SecurityStaffList extends StatelessWidget {
  const _SecurityStaffList();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SecurityStaffProvider>();

    if (provider.isLoading && provider.activeStaff.isEmpty) {
      return const ShimmerDashboard();
    }

    if (provider.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                'Failed to load staff',
                style: AppTextStyles.subheading(
                    color: Theme.of(context).colorScheme.onSurface),
              ),
              const SizedBox(height: 8),
              Text(
                'Check your connection and try again.',
                style: AppTextStyles.bodySmall(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () =>
                    context.read<SecurityStaffProvider>().retry(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry',
                    style: TextStyle(fontFamily: 'Poppins')),
              ),
            ],
          ),
        ),
      );
    }

    final staff = provider.activeStaff;

    if (staff.isEmpty) {
      return const EmptyState(
        title: 'No Security Staff',
        subtitle: 'Tap "Add Staff" to add your first watchman or security guard.',
        icon: Icons.security_rounded,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: staff.length,
      itemBuilder: (context, i) => _SecurityStaffCard(staff: staff[i]),
    );
  }
}

// ── Staff card ────────────────────────────────────────────────────────────────

class _SecurityStaffCard extends StatelessWidget {
  final SecurityStaffModel staff;
  const _SecurityStaffCard({required this.staff});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final salaries = context.watch<SecurityStaffProvider>().salaries;
    final salary = salaries[staff.id];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: isDark
            ? Border.all(color: AppColors.darkBorder.withValues(alpha: 0.6))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: avatar, name, designation, status badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StaffAvatar(name: staff.name),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(staff.name,
                          style: AppTextStyles.subheading(color: cs.onSurface)),
                      const SizedBox(height: 2),
                      Text(staff.designation,
                          style: AppTextStyles.caption(
                              color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                _StatusBadge(isActive: staff.isActive),
              ],
            ),
            const SizedBox(height: 12),
            // Info row: mobile, shift
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                _InfoChip(
                  icon: Icons.phone_outlined,
                  label: staff.mobileNumber,
                ),
                if (staff.shift != null)
                  _InfoChip(
                    icon: Icons.schedule_outlined,
                    label: staff.shift!,
                  ),
                if (salary != null)
                  _InfoChip(
                    icon: Icons.currency_rupee_rounded,
                    label:
                        '₹${(salary.monthlySalaryPaise / 100).toStringAsFixed(0)}/mo',
                    color: AppColors.paid,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddEditSecurityStaffScreen(
                          existingStaff: staff,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: Text('Edit',
                        style: AppTextStyles.caption(color: cs.primary)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _showDeactivateSheet(context, staff),
                    icon: const Icon(Icons.person_off_outlined,
                        size: 16, color: AppColors.overdue),
                    label: Text('Deactivate',
                        style: AppTextStyles.caption(
                            color: AppColors.overdue)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: const BorderSide(
                          color: AppColors.overdue, width: 1),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeactivateSheet(
      BuildContext context, SecurityStaffModel staff) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: _DeactivateSheet(staff: staff),
        ),
      ),
    );
  }
}

// ── Deactivate confirmation sheet ─────────────────────────────────────────────

class _DeactivateSheet extends StatelessWidget {
  final SecurityStaffModel staff;
  const _DeactivateSheet({required this.staff});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.overdue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_off_rounded,
                  color: AppColors.overdue, size: 36),
            ),
            const SizedBox(height: 16),
            Text('Deactivate Staff?',
                style: AppTextStyles.heading3(color: cs.onSurface)),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                '${staff.name} will be marked as inactive and removed from '
                'the active staff list. You can re-add them later.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall(color: cs.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
                      onPressed: () async {
                        Navigator.pop(context);
                        final auth = context.read<AuthProvider>();
                        final presidentId =
                            auth.currentUser?.id ?? '';
                        final error = await context
                            .read<SecurityStaffProvider>()
                            .deactivateStaff(
                              staff.id,
                              staff.apartmentId,
                              presidentId,
                            );
                        if (!context.mounted) return;
                        if (error != null) {
                          AppUtils.showSnackBar(context,
                              'Failed to deactivate: $error',
                              isError: true);
                        } else {
                          AppUtils.showSnackBar(
                              context, '${staff.name} deactivated');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.overdue,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Deactivate',
                          style: AppTextStyles.buttonText(
                              color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _StaffAvatar extends StatelessWidget {
  final String name;
  const _StaffAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(' ').take(2).map((w) => w[0]).join().toUpperCase();
    return CircleAvatar(
      radius: 24,
      backgroundColor: AppColors.blue.withValues(alpha: 0.15),
      child: Text(
        initials,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.blue,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.paid : AppColors.overdue;
    final label = isActive ? 'Active' : 'Inactive';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _InfoChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.caption(color: c)),
      ],
    );
  }
}
