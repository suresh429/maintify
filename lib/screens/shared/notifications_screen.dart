import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/complaint_provider.dart';
import '../../providers/bill_provider.dart';
import '../../models/notification_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/app_utils.dart';
import 'chat_screen.dart';
import '../president/monthly_bill_detail_screen.dart';
import '../resident/monthly_bill_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _showUnreadOnly = false;

  // initState intentionally has no auto-mark-all-read logic.
  // Notifications are marked read only when the user explicitly taps them
  // (see _NotificationTile._handleTap and _GroupedComplaintTile._handleTap).
  // The "Mark all read" action button in the AppBar handles bulk marking.

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final role = auth.role;
    final notifProvider = context.watch<NotificationProvider>();
    final theme = RoleTheme.of(role ?? UserRole.resident);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWeb = MediaQuery.sizeOf(context).width >= 600;

    // Resident and President both use the grouped complaint view.
    // Admin uses the existing flat list.
    final bool useGroupedView =
        role == UserRole.resident || role == UserRole.president;

    // ── Data preparation ───────────────────────────────────────────────────
    final List<NotifDisplayItem> groupedItems;
    final List<NotificationModel> flatItems;
    final int unreadCount;

    if (useGroupedView) {
      final allGrouped = notifProvider.groupedForResident();
      groupedItems = _showUnreadOnly
          ? allGrouped.where((i) => i.hasUnread).toList()
          : List.of(allGrouped);
      flatItems = const [];
      unreadCount = allGrouped.where((i) => i.hasUnread).length;
    } else {
      groupedItems = const [];
      final all =
          role != null ? notifProvider.forRole(role) : <NotificationModel>[];
      flatItems =
          _showUnreadOnly ? all.where((n) => !n.isRead).toList() : List.of(all);
      unreadCount = role != null
          ? notifProvider.forRole(role).where((n) => !n.isRead).length
          : 0;
    }

    final int itemCount =
        useGroupedView ? groupedItems.length : flatItems.length;

    return Scaffold(
      backgroundColor: isWeb
          ? (isDark ? const Color(0xFF0F172A) : const Color(0xFFF3F4F6))
          : cs.surface,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : cs.surface,
        elevation: isDark ? 0 : 1,
        shadowColor: cs.shadow.withValues(alpha: 0.08),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : cs.onSurface, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications',
          style: AppTextStyles.heading3(
              color: isDark ? Colors.white : cs.onSurface),
        ),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () {
                final userId = auth.currentUser?.id;
                if (userId != null) {
                  notifProvider.markAllRead(userId);
                }
              },
              child: Text(
                'Mark all read',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.effectivePrimary(context),
                ),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ── Filter chips ───────────────────────────────────────────────
          _buildFilterBar(context, theme, unreadCount, isDark, isWeb),

          // ── Notification list ──────────────────────────────────────────
          Expanded(
            child: itemCount == 0
                ? _buildEmpty(context, isDark)
                : ListView.builder(
                    padding: isWeb
                        ? const EdgeInsets.symmetric(vertical: 12)
                        : const EdgeInsets.all(8),
                    itemCount: itemCount,
                    itemBuilder: (_, i) {
                      Widget tile;
                      if (useGroupedView) {
                        final item = groupedItems[i];
                        tile = item.isGrouped
                            ? _GroupedComplaintTile(
                                item: item,
                                theme: theme,
                                isAdminView: role == UserRole.president,
                              )
                            : _NotificationTile(
                                notification: item.representative,
                                theme: theme,
                              );
                      } else {
                        tile = _NotificationTile(
                          notification: flatItems[i],
                          theme: theme,
                        );
                      }
                      if (isWeb) {
                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 680),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 2),
                              child: tile,
                            ),
                          ),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: tile,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, RoleTheme theme, int unreadCount,
      bool isDark, bool isWeb) {
    final cs = Theme.of(context).colorScheme;
    final accent = theme.effectivePrimary(context);

    Widget bar = Container(
      color: isDark ? const Color(0xFF1E293B) : cs.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _FilterChip(
            label: 'All',
            isSelected: !_showUnreadOnly,
            accent: accent,
            isDark: isDark,
            onTap: () => setState(() => _showUnreadOnly = false),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: unreadCount > 0 ? 'Unread ($unreadCount)' : 'Unread',
            isSelected: _showUnreadOnly,
            accent: accent,
            isDark: isDark,
            onTap: () => setState(() => _showUnreadOnly = true),
          ),
        ],
      ),
    );

    if (isWeb) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: bar,
        ),
      );
    }
    return bar;
  }

  Widget _buildEmpty(BuildContext context, bool isDark) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _showUnreadOnly
                  ? Icons.mark_email_read_outlined
                  : Icons.notifications_off_outlined,
              size: 48,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _showUnreadOnly ? 'No Unread Notifications' : 'No Notifications',
            style: AppTextStyles.heading3(color: cs.onSurface),
          ),
          const SizedBox(height: 6),
          Text(
            _showUnreadOnly ? 'You\'re all caught up!' : 'Nothing here yet.',
            style: AppTextStyles.caption(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color accent;
  final bool isDark;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.accent,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: 0.12)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.grey.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: accent.withValues(alpha: 0.4), width: 1)
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? accent
                : (isDark ? Colors.white70 : Colors.grey[600]),
          ),
        ),
      ),
    );
  }
}

// ── Notification tile ─────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final RoleTheme theme;

  const _NotificationTile({
    required this.notification,
    required this.theme,
  });

  IconData _iconForType(String type) {
    switch (type) {
      case NotificationType.bill:
      case NotificationType.billUpdated:
        return Icons.receipt_long_outlined;
      case NotificationType.billDeleted:
        return Icons.receipt_long_outlined;
      case NotificationType.payment:
      case NotificationType.paymentReceived:
      case NotificationType.paymentApproved:
        return Icons.payments_outlined;
      case NotificationType.paymentRejected:
        return Icons.money_off_outlined;
      case NotificationType.complaint:
      case NotificationType.complaintReply:
        return Icons.chat_bubble_outline_rounded;
      case NotificationType.complaintClosed:
        return Icons.check_circle_outline_rounded;
      case NotificationType.meeting:
      case NotificationType.meetingUpdated:
        return Icons.event_rounded;
      case NotificationType.meetingCancelled:
        return Icons.event_busy_outlined;
      case NotificationType.presidentTransfer:
        return Icons.swap_horiz_rounded;
      case NotificationType.residentRegistered:
        return Icons.person_add_outlined;
      default:
        return Icons.info_outline_rounded;
    }
  }

  // ── Tap navigation ──────────────────────────────────────────────────────────

  void _handleTap(BuildContext context) {
    final refId = notification.referenceId ?? '';
    final type  = notification.type;
    final role  = context.read<AuthProvider>().role;

    debugPrint('[NOTIF-TAP] ══════════════════════════════════════');
    debugPrint('[NOTIF-TAP] _handleTap fired');
    debugPrint('[NOTIF-TAP] type: $type');
    debugPrint('[NOTIF-TAP] referenceId: $refId');
    debugPrint('[NOTIF-TAP]   role:  $role');

    // Mark this notification as read immediately (optimistic).
    // For grouped complaint tiles this is handled by markComplaintGroupRead;
    // for all single/flat-list tiles this call is the sole read trigger.
    context.read<NotificationProvider>().markRead(notification.id);

    // Complaint types → ChatScreen (read-only for admin, interactive for resident)
    if (type == NotificationType.complaint ||
        type == NotificationType.complaintReply ||
        type == NotificationType.complaintClosed) {
      debugPrint('[NOTIF-TAP]   branch: complaint');
      if (refId.isEmpty) {
        debugPrint('[NOTIF-TAP]   refId is empty — returning');
        return;
      }
      final complaint = context.read<ComplaintProvider>().findComplaint(refId);
      debugPrint('[NOTIF-TAP]   findComplaint("$refId") → ${complaint == null ? "NULL" : "found: ${complaint.id}"}');
      if (complaint == null) {
        debugPrint('[NOTIF-TAP]   complaint not in cache — returning');
        return;
      }
      final userId    = context.read<AuthProvider>().currentUser?.id;
      final isAdmin   = role == UserRole.president;
      debugPrint('[NOTIF-TAP]   pushing ChatScreen (isAdminView: $isAdmin)');
      try {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              complaint:     complaint,
              isAdminView:   isAdmin,
              currentUserId: userId,
            ),
          ),
        );
        debugPrint('[NOTIF-TAP]   Navigator.push ChatScreen succeeded');
      } catch (e, stack) {
        debugPrint('[NOTIF-TAP]   Navigator.push ChatScreen EXCEPTION: $e');
        debugPrint('[NOTIF-TAP]   stack: $stack');
      }
      return;
    }

    // Bill types → role-specific bill detail screen
    if (type == NotificationType.bill ||
        type == NotificationType.billUpdated ||
        type == NotificationType.billDeleted) {
      debugPrint('[NOTIF-TAP]   branch: bill');
      if (refId.isEmpty) {
        debugPrint('[NOTIF-TAP]   refId is empty — returning');
        return;
      }
      _navigateToBill(context, refId, role);
      return;
    }

    // Payment types — referenceId is billId for these notifications
    if (type == NotificationType.paymentReceived ||
        type == NotificationType.paymentApproved ||
        type == NotificationType.paymentRejected) {
      debugPrint('[NOTIF-TAP]   branch: payment');
      if (refId.isEmpty) {
        debugPrint('[NOTIF-TAP]   refId is empty — returning');
        return;
      }
      _navigateToBill(context, refId, role);
      return;
    }

    // Other types (meeting, president_transfer, resident_registered, system)
    debugPrint('[NOTIF-TAP]   type "$type" has no detail screen — no-op');
    debugPrint('[NOTIF-TAP] ══════════════════════════════════════');
  }

  void _navigateToBill(BuildContext context, String refId, UserRole? role) {
    final auth      = context.read<AuthProvider>();
    final aptId     = auth.currentUser?.apartmentId ?? '';
    final billProvider = context.read<BillProvider>();

    debugPrint('[NOTIF-TAP]   _navigateToBill refId="$refId" role=$role aptId="$aptId"');

    if (role == UserRole.president) {
      // President sees MonthlyBillDetailScreen — find the summary containing this bill.
      if (aptId.isEmpty) {
        debugPrint('[NOTIF-TAP]   aptId empty — returning');
        return;
      }
      final summaries = billProvider.monthlyBillsForApartment(aptId);
      debugPrint('[NOTIF-TAP]   monthlyBillsForApartment count: ${summaries.length}');
      MonthlyBillSummary? target;
      for (final s in summaries) {
        debugPrint('[NOTIF-TAP]     summary month=${s.month}  bills=${s.bills.map((b) => b.id).toList()}');
        if (s.bills.any((b) => b.id == refId)) {
          target = s;
          break;
        }
      }
      debugPrint('[NOTIF-TAP]   target summary: ${target == null ? "NOT FOUND" : target.month}');
      if (target == null) {
        debugPrint('[NOTIF-TAP]   bill not in any summary — returning');
        return;
      }
      try {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MonthlyBillDetailScreen(summary: target!, aptId: aptId),
          ),
        );
        debugPrint('[NOTIF-TAP]   Navigator.push MonthlyBillDetailScreen succeeded');
      } catch (e, stack) {
        debugPrint('[NOTIF-TAP]   Navigator.push MonthlyBillDetailScreen EXCEPTION: $e');
        debugPrint('[NOTIF-TAP]   stack: $stack');
      }
    } else if (role == UserRole.resident) {
      // Resident sees ResidentMonthlyBillDetailScreen — find via month string.
      final userId    = auth.currentUser?.id ?? '';
      final billMonth = billProvider.monthForBill(refId);
      debugPrint('[NOTIF-TAP]   monthForBill("$refId") → ${billMonth == null ? "NULL" : '"$billMonth"'}');
      if (billMonth == null || aptId.isEmpty) {
        debugPrint('[NOTIF-TAP]   billMonth null or aptId empty — returning');
        return;
      }
      final summaries = billProvider.userMonthlySummaries(userId);
      debugPrint('[NOTIF-TAP]   userMonthlySummaries count: ${summaries.length}');
      UserMonthlySummary? target;
      try {
        target = summaries.firstWhere((s) => s.month == billMonth);
      } catch (_) {
        debugPrint('[NOTIF-TAP]   no UserMonthlySummary for month "$billMonth" — returning');
        return;
      }
      debugPrint('[NOTIF-TAP]   pushing ResidentMonthlyBillDetailScreen month=${target.month}');
      try {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ResidentMonthlyBillDetailScreen(
              summary: target!,
              aptId:   aptId,
            ),
          ),
        );
        debugPrint('[NOTIF-TAP]   Navigator.push ResidentMonthlyBillDetailScreen succeeded');
      } catch (e, stack) {
        debugPrint('[NOTIF-TAP]   Navigator.push ResidentMonthlyBillDetailScreen EXCEPTION: $e');
        debugPrint('[NOTIF-TAP]   stack: $stack');
      }
    } else {
      debugPrint('[NOTIF-TAP]   role is admin/null — no bill detail screen');
    }
    debugPrint('[NOTIF-TAP] ══════════════════════════════════════');
  }

  Color _colorForType(String type, bool isDark) {
    switch (type) {
      case NotificationType.bill:
      case NotificationType.billUpdated:
        return AppColors.pending;
      case NotificationType.billDeleted:
        return isDark ? const Color(0xFFFC8181) : AppColors.overdue;
      case NotificationType.payment:
      case NotificationType.paymentReceived:
      case NotificationType.paymentApproved:
        return AppColors.paid;
      case NotificationType.paymentRejected:
        return isDark ? const Color(0xFFFC8181) : AppColors.overdue;
      case NotificationType.complaint:
      case NotificationType.complaintReply:
        return isDark ? const Color(0xFF60A5FA) : AppColors.blue;
      case NotificationType.complaintClosed:
        return AppColors.paid;
      case NotificationType.meeting:
      case NotificationType.meetingUpdated:
        return isDark ? const Color(0xFFA78BFA) : AppColors.purple;
      case NotificationType.meetingCancelled:
        return isDark ? const Color(0xFFFC8181) : AppColors.overdue;
      case NotificationType.presidentTransfer:
      case NotificationType.residentRegistered:
        return isDark ? const Color(0xFFA78BFA) : AppColors.purple;
      default:
        return isDark ? const Color(0xFFA78BFA) : AppColors.purple;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = theme.effectivePrimary(context);
    final typeColor = _colorForType(notification.type, isDark);
    final isUnread = !notification.isRead;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _handleTap(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isUnread
                ? (isDark
                    ? accent.withValues(alpha: 0.07)
                    : accent.withValues(alpha: 0.05))
                : (isDark ? const Color(0xFF1E293B) : cs.surface),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isUnread
                  ? accent.withValues(alpha: 0.18)
                  : cs.outlineVariant.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon badge
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(_iconForType(notification.type),
                    color: typeColor, size: 20),
              ),
              const SizedBox(width: 12),

              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: AppTextStyles.subheading(color: cs.onSurface).copyWith(
                        fontWeight:
                            isUnread ? FontWeight.w700 : FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notification.body,
                      style: AppTextStyles.bodySmall(
                          color: cs.onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppUtils.timeAgo(notification.createdAt),
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isUnread ? accent : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Unread dot
              if (isUnread) ...[
                const SizedBox(width: 8),
                Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Grouped complaint tile (resident-only) ────────────────────────────────────

/// Tile for a group of complaint notifications sharing the same [referenceId].
/// Displays the latest notification's content and a badge with the unread count.
/// Tapping marks the whole group read and opens ChatScreen.
class _GroupedComplaintTile extends StatelessWidget {
  final NotifDisplayItem item;
  final RoleTheme theme;
  final bool isAdminView;

  const _GroupedComplaintTile({
    required this.item,
    required this.theme,
    required this.isAdminView,
  });

  void _handleTap(BuildContext context) {
    final referenceId = item.groupReferenceId!;
    debugPrint('[NOTIF-TAP] ══════════════════════════════════════');
    debugPrint('[NOTIF-TAP] _handleTap (grouped complaint)');
    debugPrint('[NOTIF-TAP] referenceId: $referenceId');
    debugPrint('[NOTIF-TAP] isAdminView: $isAdminView');

    final complaint =
        context.read<ComplaintProvider>().findComplaint(referenceId);
    debugPrint(
        '[NOTIF-TAP] findComplaint("$referenceId") → ${complaint == null ? "NULL" : "found: ${complaint.id}"}');
    if (complaint == null) {
      debugPrint('[NOTIF-TAP] complaint not in cache — returning');
      return;
    }

    // Mark all notifications in this group read before navigating.
    context.read<NotificationProvider>().markComplaintGroupRead(referenceId);

    final userId = context.read<AuthProvider>().currentUser?.id;
    debugPrint('[NOTIF-TAP] pushing ChatScreen (isAdminView: $isAdminView)');
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            complaint: complaint,
            isAdminView: isAdminView,
            currentUserId: userId,
          ),
        ),
      );
      debugPrint('[NOTIF-TAP] Navigator.push ChatScreen succeeded');
    } catch (e, stack) {
      debugPrint('[NOTIF-TAP] Navigator.push ChatScreen EXCEPTION: $e');
      debugPrint('[NOTIF-TAP] stack: $stack');
    }
    debugPrint('[NOTIF-TAP] ══════════════════════════════════════');
  }

  @override
  Widget build(BuildContext context) {
    final n = item.representative;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = theme.effectivePrimary(context);
    final typeColor =
        isDark ? const Color(0xFF60A5FA) : AppColors.blue;
    final isUnread = item.hasUnread;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _handleTap(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isUnread
                ? (isDark
                    ? accent.withValues(alpha: 0.07)
                    : accent.withValues(alpha: 0.05))
                : (isDark ? const Color(0xFF1E293B) : cs.surface),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isUnread
                  ? accent.withValues(alpha: 0.18)
                  : cs.outlineVariant.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.chat_bubble_outline_rounded,
                    color: typeColor, size: 20),
              ),
              const SizedBox(width: 12),

              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.title,
                      style:
                          AppTextStyles.subheading(color: cs.onSurface).copyWith(
                        fontWeight:
                            isUnread ? FontWeight.w700 : FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      n.body,
                      style:
                          AppTextStyles.bodySmall(color: cs.onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppUtils.timeAgo(n.createdAt),
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color:
                            isUnread ? accent : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Unread count badge (replaces simple dot for grouped complaints)
              if (item.unreadCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${item.unreadCount}',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
