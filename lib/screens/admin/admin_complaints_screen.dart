import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../models/complaint_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/complaint_provider.dart';
import '../../providers/apartment_provider.dart';
import '../../widgets/pill_filter_bar.dart';
import '../shared/chat_screen.dart';

class AdminComplaintsScreen extends StatefulWidget {
  const AdminComplaintsScreen({super.key});

  @override
  State<AdminComplaintsScreen> createState() => _AdminComplaintsScreenState();
}

class _AdminComplaintsScreenState extends State<AdminComplaintsScreen> {
  String _filter = 'All';

  static const List<String> _filters = [
    'All',
    ComplaintStatus.open,
    ComplaintStatus.inProgress,
    ComplaintStatus.resolved,
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser!;
    final aptId = user.apartmentId ?? '';
    final apt = context.read<ApartmentProvider>().findById(aptId);

    return Consumer<ComplaintProvider>(
      builder: (_, prov, __) {
        final all = prov.complaintsForApartment(aptId);
        final filtered = _filter == 'All'
            ? all
            : all.where((c) => c.status == _filter).toList();

        final cs = Theme.of(context).colorScheme;
        return Scaffold(
          body: Column(
            children: [
              // Apartment info banner
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: cs.surface,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: RoleTheme.of(UserRole.admin).effectivePrimary(context).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.apartment_rounded,
                          color: RoleTheme.of(UserRole.admin).effectivePrimary(context), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        apt?.name ?? 'Apartment',
                        style: AppTextStyles.subheading(color: cs.onSurface),
                      ),
                    ),
                    _CountBadge(
                        count: all
                            .where((c) => c.status == ComplaintStatus.open)
                            .length,
                        label: 'Open'),
                  ],
                ),
              ),

              // Modern pill filter bar
              Container(
                color: cs.surface,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: PillFilterBar(
                  options: _filters,
                  selected: _filter,
                  activeColor: RoleTheme.of(UserRole.admin).effectivePrimary(context),
                  onChanged: (f) => setState(() => _filter = f),
                ),
              ),

              const Divider(height: 1),

              // Complaints list
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline,
                                size: 52,
                                color: (Theme.of(context).brightness == Brightness.dark
                                        ? const Color(0xFF60A5FA)
                                        : AppColors.blue)
                                    .withOpacity(0.4)),
                            const SizedBox(height: 12),
                            Text('No complaints',
                                style: AppTextStyles.subheading(color: cs.onSurface)),
                            const SizedBox(height: 4),
                            Text(
                              _filter == 'All'
                                  ? 'No complaints from residents yet'
                                  : 'No $_filter complaints',
                              style: AppTextStyles.bodySmall(
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _AdminComplaintTile(
                          complaint: filtered[i],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                complaint: filtered[i],
                                isAdminView: true,
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Admin Complaint Tile ──────────────────────────────────────────────────────

class _AdminComplaintTile extends StatelessWidget {
  final ComplaintModel complaint;
  final VoidCallback onTap;

  const _AdminComplaintTile(
      {required this.complaint, required this.onTap});

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
    final unread = complaint.status == ComplaintStatus.open &&
        (lastMsg?.isFromAdmin == false);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = RoleTheme.of(UserRole.admin).effectivePrimary(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: unread
              ? Border.all(color: accent.withOpacity(0.3))
              : null,
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
                color: accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  Icon(_categoryIcon, color: accent, size: 20),
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
                          style: AppTextStyles.subheading(
                                  color: cs.onSurface)
                              .copyWith(
                                  fontWeight: unread
                                      ? FontWeight.w700
                                      : FontWeight.w600),
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
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.person_outline,
                          size: 13, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        '${complaint.userName} · ${complaint.unit}',
                        style: AppTextStyles.caption(
                            color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                  if (lastMsg != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      lastMsg.isFromAdmin
                          ? 'You: ${lastMsg.content}'
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
                          status: complaint.status,
                          color: _statusColor),
                      const SizedBox(width: 8),
                      Text(complaint.category,
                          style: AppTextStyles.caption(
                              color: cs.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                Icon(Icons.chevron_right_rounded,
                    color: cs.onSurfaceVariant, size: 20),
                if (unread)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
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

class _CountBadge extends StatelessWidget {
  final int count;
  final String label;
  const _CountBadge({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: count > 0
            ? AppColors.pending.withOpacity(0.1)
            : AppColors.paid.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: count > 0 ? AppColors.pending : AppColors.paid,
        ),
      ),
    );
  }
}
