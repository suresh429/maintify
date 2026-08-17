import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_utils.dart';
import '../../models/complaint_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/complaint_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/bottom_sheet_container.dart';
import '../../widgets/chat_bubble.dart';
import '../../widgets/chat_input_field.dart';

/// Shared chat screen used by both User and Admin.
/// [isAdminView] controls the gradient/color theme and which side admin sees.
/// [currentUserId] determines whether the input field is shown for non-admin,
/// non-owner views (read-only mode when complaint.userId != currentUserId).
class ChatScreen extends StatefulWidget {
  final ComplaintModel complaint;
  final bool isAdminView;
  final String? currentUserId;

  const ChatScreen({
    super.key,
    required this.complaint,
    this.isAdminView = false,
    this.currentUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Subscribe to real-time Firestore messages subcollection
      context
          .read<ComplaintProvider>()
          .subscribeToMessages(widget.complaint.id);
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  List<Color> get _gradient =>
      widget.isAdminView ? AppColors.adminGradient : AppColors.userGradient;

  Color get _primary =>
      widget.isAdminView ? AppColors.blue : AppColors.green;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser!;

    return Consumer<ComplaintProvider>(
      builder: (context, complaintProv, _) {
        // Always use the live complaint from the provider so status updates
        // in the AppBar chip reflect immediately without needing setState().
        final complaint = complaintProv.findComplaint(widget.complaint.id)
            ?? widget.complaint;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              complaint.title,
              style: AppTextStyles.subheading(color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              complaint.category,
              style: AppTextStyles.caption(
                      color: Colors.white.withValues(alpha: 0.8))
                  .copyWith(fontSize: 11),
            ),
          ],
        ),
        actions: [
          _StatusChip(
            status: complaint.status,
            onTap: widget.isAdminView ? () => _showStatusSheet() : null,
          ),
          const SizedBox(width: 8),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _gradient,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: Consumer<ComplaintProvider>(
              builder: (_, prov, __) {
                final messages = prov.messagesForComplaint(complaint.id);
                final isReadOnly = _isReadOnly(complaint, user);

                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());

                return ListView(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  children: [
                    _buildDescriptionCard(context, complaint),
                    if (messages.isEmpty)
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 36,
                                color: _primary.withValues(alpha: 0.25)),
                            const SizedBox(height: 8),
                            Text(
                              isReadOnly
                                  ? 'No messages yet'
                                  : 'No messages yet',
                              style: AppTextStyles.bodyMedium(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                            ),
                            if (!isReadOnly) ...[
                              const SizedBox(height: 4),
                              Text('Start the conversation below',
                                  style: AppTextStyles.caption(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant)),
                            ],
                          ],
                        ),
                      )
                    else ...[
                      _buildSectionHeader(context, 'Conversation'),
                      ...messages.asMap().entries.expand((entry) {
                        final i = entry.key;
                        final msg = entry.value;
                        final showDate = i == 0 ||
                            !_isSameDay(messages[i - 1].timestamp,
                                msg.timestamp);
                        // Mask sender identity for read-only (non-owner) residents
                        final effectiveName =
                            (!widget.isAdminView &&
                                    isReadOnly &&
                                    !msg.isFromAdmin)
                                ? 'Resident'
                                : msg.senderName;
                        return [
                          if (showDate)
                            ChatDateSeparator(date: msg.timestamp),
                          ChatBubble(
                            content: msg.content,
                            senderName: effectiveName,
                            timestamp: msg.timestamp,
                            isFromAdmin: msg.isFromAdmin,
                            showSenderName: false,
                            showAvatar: !(widget.isAdminView &&
                                !msg.isFromAdmin),
                          ),
                        ];
                      }),
                    ],
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
          ),

          // Input field (or read-only note)
          _buildBottomBar(context, complaint, user),
        ],
      ),
    );
      }, // Consumer builder
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Returns true when this user is viewing someone else's complaint and is
  /// not an admin — in that case the chat is read-only.
  bool _isReadOnly(ComplaintModel complaint, user) {
    if (widget.isAdminView) return false;
    final effectiveUserId = widget.currentUserId ?? user.id;
    return complaint.userId != effectiveUserId;
  }

  Widget _buildBottomBar(
      BuildContext context, ComplaintModel complaint, user) {
    final cs = Theme.of(context).colorScheme;

    if (_isReadOnly(complaint, user)) {
      return Container(
        padding: const EdgeInsets.all(14),
        color: cs.surface,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, color: cs.onSurfaceVariant, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Only the resident who reported this complaint and the President can participate in the conversation.',
                style: AppTextStyles.caption(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    if (complaint.status == ComplaintStatus.resolved) {
      return Container(
        padding: const EdgeInsets.all(14),
        color: cs.surface,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_rounded,
                color: AppColors.paid, size: 16),
            const SizedBox(width: 6),
            Text(
              'This complaint has been resolved',
              style: AppTextStyles.caption(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return ChatInputField(
      sendGradient: _gradient,
      onSend: (text) async {
        await context.read<ComplaintProvider>().sendMessage(
              complaintId: complaint.id,
              senderId: user.id,
              senderName: user.name,
              isFromAdmin: widget.isAdminView,
              content: text,
              notificationProvider: context.read<NotificationProvider>(),
            );
        _scrollToBottom();
      },
    );
  }

  void _showStatusSheet() {
    const statusOrder = [
      ComplaintStatus.open,
      ComplaintStatus.inProgress,
      ComplaintStatus.resolved,
    ];

    // Use live complaint status from provider, not the stale widget field
    final liveComplaint = context.read<ComplaintProvider>().findComplaint(widget.complaint.id)
        ?? widget.complaint;
    final currentIndex = statusOrder.indexOf(liveComplaint.status);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BottomSheetContainer(
        title: 'Update Status',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: statusOrder.asMap().entries.map((entry) {
            final idx = entry.key;
            final s = entry.value;
            final isCurrent = idx == currentIndex;
            // Only allow moving forward (higher index), not backward
            final isAllowed = idx > currentIndex;
            final cs = Theme.of(context).colorScheme;

            return ListTile(
              contentPadding: EdgeInsets.zero,
              enabled: isAllowed,
              leading: Icon(
                _statusIcon(s),
                color: isAllowed || isCurrent
                    ? _statusColor(s)
                    : cs.onSurface.withValues(alpha: 0.3),
              ),
              title: Text(
                s,
                style: AppTextStyles.bodyMedium(
                  color: isAllowed
                      ? cs.onSurface
                      : cs.onSurface.withValues(alpha: isCurrent ? 1.0 : 0.35),
                ).copyWith(
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
              trailing: isCurrent
                  ? const Icon(Icons.check_rounded, color: AppColors.green)
                  : null,
              onTap: isAllowed
                  ? () async {
                      Navigator.pop(ctx);
                      await context
                          .read<ComplaintProvider>()
                          .updateStatus(widget.complaint.id, s);
                    }
                  : null,
            );
          }).toList(),
        ),
      ),
    );
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case ComplaintStatus.open:
        return Icons.radio_button_unchecked;
      case ComplaintStatus.inProgress:
        return Icons.timelapse_rounded;
      case ComplaintStatus.resolved:
        return Icons.check_circle_rounded;
      default:
        return Icons.circle_outlined;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case ComplaintStatus.open:
        return AppColors.pending;
      case ComplaintStatus.inProgress:
        return AppColors.teal;
      case ComplaintStatus.resolved:
        return AppColors.paid;
      default:
        return AppColors.pending;
    }
  }

  Widget _buildDescriptionCard(BuildContext context, ComplaintModel complaint) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person_outline_rounded,
                      color: _primary, size: 17),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.isAdminView
                            ? complaint.userName
                            : 'Reported by Resident',
                        style: AppTextStyles.label(color: cs.onSurface),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.isAdminView
                            ? 'Flat ${complaint.unit} · ${AppUtils.timeAgo(complaint.createdAt)}'
                            : AppUtils.timeAgo(complaint.createdAt),
                        style: AppTextStyles.caption(
                            color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (complaint.content.isNotEmpty) ...[
            Divider(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.3)),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.notes_rounded,
                        size: 13, color: cs.onSurfaceVariant),
                    const SizedBox(width: 5),
                    Text('Description',
                        style: AppTextStyles.caption(
                            color: cs.onSurfaceVariant)),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    complaint.content,
                    style: AppTextStyles.bodySmall(color: cs.onSurface)
                        .copyWith(height: 1.65),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Expanded(
            child: Divider(
                color: cs.outlineVariant.withValues(alpha: 0.5))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            title,
            style:
                AppTextStyles.caption(color: cs.onSurfaceVariant),
          ),
        ),
        Expanded(
            child: Divider(
                color: cs.outlineVariant.withValues(alpha: 0.5))),
      ]),
    );
  }
}

// ── Status chip shown in AppBar ───────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String status;
  final VoidCallback? onTap;

  const _StatusChip({required this.status, this.onTap});

  Color get _color {
    switch (status) {
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              status,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 3),
              const Icon(Icons.expand_more_rounded,
                  color: Colors.white, size: 14),
            ],
          ],
        ),
      ),
    );
  }
}
