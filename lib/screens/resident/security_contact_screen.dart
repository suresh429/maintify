import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../models/security_staff_model.dart';
import '../../providers/security_staff_provider.dart';
import '../../widgets/shimmer_loading.dart';

class SecurityContactScreen extends StatelessWidget {
  const SecurityContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = RoleTheme.of(UserRole.resident);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text('Security & Watchman',
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
      body: const _SecurityContactList(),
    );
  }
}

class _SecurityContactList extends StatelessWidget {
  const _SecurityContactList();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SecurityStaffProvider>();

    if (provider.isLoading && provider.activeStaff.isEmpty) {
      return const ShimmerDashboard();
    }

    if (provider.error != null && provider.activeStaff.isEmpty) {
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
        subtitle: 'No security staff added yet. Contact your apartment president.',
        icon: Icons.security_rounded,
      );
    }

    final salaries = provider.salaries;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: staff.length,
      itemBuilder: (context, i) => _SecurityContactCard(
        staff: staff[i],
        salary: salaries[staff[i].id],
      ),
    );
  }
}

class _SecurityContactCard extends StatelessWidget {
  final SecurityStaffModel staff;
  final SecurityStaffSalary? salary;
  const _SecurityContactCard({required this.staff, this.salary});

  Future<void> _launchCall(BuildContext context, String mobile) async {
    final uri = Uri(scheme: 'tel', path: mobile);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open phone app')),
        );
      }
    }
  }

  Future<void> _launchWhatsApp(BuildContext context, String mobile) async {
    // Strip leading '+' for WhatsApp URL — use country code directly
    final number = mobile.startsWith('+') ? mobile.substring(1) : mobile;
    // Try direct WhatsApp app scheme first, fall back to wa.me
    final appUri = Uri.parse('whatsapp://send?phone=$number');
    final webUri = Uri.parse('https://wa.me/$number');
    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri, mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WhatsApp not installed')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            // Top row
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
                          style: AppTextStyles.subheading(
                              color: cs.onSurface)),
                      const SizedBox(height: 2),
                      Text(staff.designation,
                          style: AppTextStyles.caption(
                              color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (staff.shift != null) _ShiftBadge(shift: staff.shift!),
              ],
            ),
            const SizedBox(height: 10),
            // Mobile number
            Row(
              children: [
                Icon(Icons.phone_outlined,
                    size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  staff.mobileNumber,
                  style: AppTextStyles.bodySmall(color: cs.onSurfaceVariant),
                ),
              ],
            ),
            // Salary row (shown only if loaded)
            if (salary != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.currency_rupee_rounded,
                      size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    '₹${salary!.monthlySalary.toStringAsFixed(0)} / month',
                    style: AppTextStyles.bodySmall(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ],
            // Address row (shown only if set)
            if (staff.address != null && staff.address!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      staff.address!,
                      style: AppTextStyles.bodySmall(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _launchCall(context, staff.mobileNumber),
                    icon: const Icon(Icons.call_rounded,
                        size: 16, color: Colors.white),
                    label: Text('Call',
                        style: AppTextStyles.caption(
                            color: Colors.white)
                            .copyWith(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.paid,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _launchWhatsApp(context, staff.mobileNumber),
                    icon: const FaIcon(FontAwesomeIcons.whatsapp,
                        size: 16, color: Colors.white),
                    label: Text('WhatsApp',
                        style: AppTextStyles.caption(
                            color: Colors.white)
                            .copyWith(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
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

class _ShiftBadge extends StatelessWidget {
  final String shift;
  const _ShiftBadge({required this.shift});

  @override
  Widget build(BuildContext context) {
    final color = shift == SecurityShift.night
        ? AppColors.purple
        : shift == SecurityShift.day
            ? AppColors.pending
            : AppColors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        shift,
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
