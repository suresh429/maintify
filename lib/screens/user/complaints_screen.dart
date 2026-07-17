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

class ComplaintsScreen extends StatelessWidget {
  const ComplaintsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser!;
    final theme = RoleTheme.of(UserRole.user);

    return Consumer<ComplaintProvider>(
      builder: (_, prov, __) {
        final complaints = prov.complaintsForUser(user.id);

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text('My Complaints',
                style: AppTextStyles.heading3(color: Colors.white)),
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
          body: complaints.isEmpty
              ? _EmptyState(onRaise: () => _showNewComplaintSheet(context, user))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: complaints.length,
                  itemBuilder: (_, i) => _ComplaintTile(
                    complaint: complaints[i],
                    theme: theme,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          complaint: complaints[i],
                          isAdminView: false,
                        ),
                      ),
                    ),
                  ),
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
  final _titleCtrl = TextEditingController();
  String _category = ComplaintCategory.maintenance;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final prov = context.read<ComplaintProvider>();
    await prov.createComplaint(
      apartmentId: widget.user.apartmentId ?? '',
      userId: widget.user.id,
      userName: widget.user.name,
      unit: widget.user.unit,
      title: _titleCtrl.text.trim(),
      category: _category,
      notificationProvider: context.read<NotificationProvider>(),
    );
    if (!mounted) return;
    Navigator.pop(context);
    AppUtils.showSnackBar(context, 'Complaint raised successfully!',
        color: AppColors.paid);
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
                            ? AppColors.paid.withOpacity(0.12)
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
              Text('Complaint Title',
                  style: AppTextStyles.label(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleCtrl,
                maxLines: 3,
                style: AppTextStyles.bodyMedium(
                    color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Describe your issue briefly...',
                  hintStyle: AppTextStyles.bodyMedium(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
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
  final VoidCallback onTap;

  const _ComplaintTile({
    required this.complaint,
    required this.theme,
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
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
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
                color: accent.withOpacity(0.08),
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
                          style: AppTextStyles.subheading(color: cs.onSurface),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        AppUtils.timeAgo(complaint.lastActivityAt),
                        style: AppTextStyles.caption(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (lastMsg != null)
                    Text(
                      lastMsg.isFromAdmin
                          ? 'Admin: ${lastMsg.content}'
                          : lastMsg.content,
                      style: AppTextStyles.bodySmall(color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _StatusBadge(
                          status: complaint.status, color: _statusColor),
                      const SizedBox(width: 8),
                      Text(
                        complaint.category,
                        style: AppTextStyles.caption(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                color: cs.onSurfaceVariant, size: 20),
          ],
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
        color: color.withOpacity(0.1),
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
                size: 64, color: AppColors.paid.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text('No Complaints',
                style:
                    AppTextStyles.heading3(color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 8),
            Text(
              'You have not raised any complaints yet.\nTap below to report an issue.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
