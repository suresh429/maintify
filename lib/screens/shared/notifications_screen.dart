import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../models/notification_model.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/app_utils.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthProvider>().currentUser?.id;
      if (userId != null) {
        context.read<NotificationProvider>().markAllRead(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final role = auth.role;
    final notifProvider = context.watch<NotificationProvider>();
    final theme = RoleTheme.of(role ?? UserRole.user);
    final notifications =
        role != null ? notifProvider.forRole(role) : <NotificationModel>[];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Notifications',
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
      body: notifications.isEmpty
          ? _buildEmpty()
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final n = notifications[i];
                return _NotificationTile(
                  notification: n,
                  theme: theme,
                );
              },
            ),
    );
  }

  Widget _buildEmpty() {
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
            child: const Icon(Icons.notifications_off_outlined,
                size: 48, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Text('No Notifications', style: AppTextStyles.heading3(color: cs.onSurface)),
          const SizedBox(height: 6),
          Text('You\'re all caught up!', style: AppTextStyles.caption(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isUnread
            ? accent.withOpacity(0.04)
            : cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: isUnread
            ? Border.all(color: accent.withOpacity(0.15))
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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_iconForType(notification.type),
                color: typeColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: AppTextStyles.subheading(color: cs.onSurface).copyWith(
                          fontWeight: isUnread
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isUnread)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(left: 6),
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notification.body,
                  style: AppTextStyles.bodySmall(color: cs.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  AppUtils.timeAgo(notification.createdAt),
                  style: AppTextStyles.caption(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
