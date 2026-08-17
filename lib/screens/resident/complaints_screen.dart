import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../models/complaint_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/complaint_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/bottom_sheet_container.dart';
import '../../widgets/common_button.dart';
import '../shared/chat_screen.dart';

/// Community Complaint Board — shows ALL complaints for the apartment.
/// Own complaints show "My Complaint" badge + full chat access.
/// Other residents' complaints show "Anonymous Resident" (no unit) + read-only view.
class ComplaintsScreen extends StatelessWidget {
  const ComplaintsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser!;
    final theme = RoleTheme.of(UserRole.resident);
    final aptId = user.apartmentId ?? '';
    final isWeb = MediaQuery.sizeOf(context).width >= 600;

    return Consumer<ComplaintProvider>(
      builder: (_, prov, __) {
        final complaints = prov.complaintsForApartment(aptId);

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: complaints.isEmpty
              ? _EmptyState(onRaise: () => _showNewComplaintSheet(context, user))
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(isWeb ? 24.0 : 16.0, 16, isWeb ? 24.0 : 16.0, 100),
                  itemCount: complaints.length,
                  itemBuilder: (_, i) {
                    final complaint = complaints[i];
                    final isOwn = complaint.userId == user.id;
                    final item = _ComplaintTile(
                      complaint: complaint,
                      theme: theme,
                      isOwn: isOwn,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              complaint: complaint,
                              isAdminView: false,
                              currentUserId: user.id,
                            ),
                          ),
                        );
                      },
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
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showNewComplaintSheet(context, user),
            backgroundColor: theme.primary,
            icon: const Icon(Icons.add_comment_outlined, color: Colors.white),
            label: Text('New Complaint',
                style: AppTextStyles.buttonText(color: Colors.white)),
          ),
        );
      },
    );
  }

  void _showNewComplaintSheet(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewComplaintSheet(user: user),
    );
  }

}

// ── New Complaint Bottom Sheet ────────────────────────────────────────────────

class _NewComplaintSheet extends StatefulWidget {
  final UserModel user;
  const _NewComplaintSheet({required this.user});

  @override
  State<_NewComplaintSheet> createState() => _NewComplaintSheetState();
}

class _NewComplaintSheetState extends State<_NewComplaintSheet> {
  final _formKey = GlobalKey<FormState>();
  final _contentCtrl = TextEditingController();
  String _category = ComplaintCategory.maintenance;

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final desc = _contentCtrl.text.trim();
      final autoTitle = desc.length > 57 ? '${desc.substring(0, 57)}...' : desc;
      await context.read<ComplaintProvider>().createComplaint(
            apartmentId: widget.user.apartmentId ?? '',
            userId: widget.user.id,
            userName: widget.user.name,
            unit: widget.user.unit,
            title: autoTitle,
            content: desc,
            category: _category,
            notificationProvider: context.read<NotificationProvider>(),
          );
      if (!mounted) return;
      Navigator.pop(context);
      AppUtils.showSnackBar(context, 'Complaint raised successfully!',
          color: AppColors.paid);
    } catch (e) {
      if (!mounted) return;
      AppUtils.showSnackBar(
          context, 'Failed to submit complaint. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ScrollableBottomSheet(
        title: 'Raise a Complaint',
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Category',
                  style: AppTextStyles.label(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ComplaintCategory.all.map((cat) {
                  final selected = _category == cat;
                  return GestureDetector(
                    onTap: () => setState(() => _category = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.paid.withValues(alpha: 0.12)
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? AppColors.paid
                              : Theme.of(context).colorScheme.outlineVariant,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: selected
                              ? AppColors.paid
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              Text('Description',
                  style: AppTextStyles.label(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _contentCtrl,
                maxLines: 4,
                style: AppTextStyles.bodyMedium(
                    color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Describe your issue in detail...',
                  hintStyle: AppTextStyles.bodyMedium(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  alignLabelWithHint: true,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please describe the issue'
                    : null,
              ),
              const SizedBox(height: 24),
              Consumer<ComplaintProvider>(
                builder: (_, prov, __) => CommonButton(
                  text: 'Submit Complaint',
                  gradient: AppColors.userGradient,
                  icon: Icons.send_outlined,
                  isLoading: prov.isLoading,
                  onPressed: _submit,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Complaint Tile ────────────────────────────────────────────────────────────

class _ComplaintTile extends StatelessWidget {
  final ComplaintModel complaint;
  final RoleTheme theme;
  final bool isOwn;
  final VoidCallback onTap;

  const _ComplaintTile({
    required this.complaint,
    required this.theme,
    required this.isOwn,
    required this.onTap,
  });

  Color get _statusColor {
    switch (complaint.status) {
      case ComplaintStatus.open:
        return AppColors.pending;
      case ComplaintStatus.inProgress:
        return AppColors.teal;
      case ComplaintStatus.resolved:
        return AppColors.paid;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData get _categoryIcon {
    switch (complaint.category) {
      case ComplaintCategory.maintenance:
        return Icons.build_outlined;
      case ComplaintCategory.billing:
        return Icons.receipt_outlined;
      case ComplaintCategory.noise:
        return Icons.volume_up_outlined;
      case ComplaintCategory.parking:
        return Icons.local_parking_outlined;
      case ComplaintCategory.amenities:
        return Icons.fitness_center_outlined;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lastMsg = complaint.lastMessage;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = theme.effectivePrimary(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_categoryIcon, color: accent, size: 20),
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          complaint.title,
                          style:
                              AppTextStyles.subheading(color: cs.onSurface),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        AppUtils.timeAgo(complaint.lastActivityAt),
                        style: AppTextStyles.caption(
                            color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Author line: "Me" for own, "Anonymous Resident" for others
                  Row(
                    children: [
                      Icon(Icons.person_outline,
                          size: 12, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        isOwn ? 'Me' : 'Anonymous Resident',
                        style: AppTextStyles.caption(
                            color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),

                  if (complaint.content.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      complaint.content,
                      style: AppTextStyles.bodySmall(
                          color: cs.onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ] else if (isOwn && lastMsg != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      lastMsg.isFromAdmin
                          ? 'Admin: ${lastMsg.content}'
                          : lastMsg.content,
                      style: AppTextStyles.bodySmall(
                          color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _StatusBadge(
                          status: complaint.status, color: _statusColor),
                      const SizedBox(width: 8),
                      Text(
                        complaint.category,
                        style: AppTextStyles.caption(
                            color: cs.onSurfaceVariant),
                      ),
                      if (isOwn) ...[
                        const Spacer(),
                        _MyComplaintBadge(),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: cs.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _MyComplaintBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
      ),
      child: Text(
        'My Complaint',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: AppColors.teal,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final Color color;
  const _StatusBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRaise;
  const _EmptyState({required this.onRaise});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined,
                size: 64,
                color: AppColors.paid.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('No Complaints',
                style: AppTextStyles.heading3(
                    color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 8),
            Text(
              'No complaints from the community yet.\nTap below to report an issue.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            CommonButton(
              text: 'Raise a Complaint',
              gradient: AppColors.userGradient,
              icon: Icons.add_comment_outlined,
              width: 220,
              onPressed: onRaise,
            ),
          ],
        ),
      ),
    );
  }
}
