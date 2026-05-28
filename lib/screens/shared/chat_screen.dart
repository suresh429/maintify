import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/complaint_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/complaint_provider.dart';
import '../../widgets/bottom_sheet_container.dart';
import '../../widgets/chat_bubble.dart';
import '../../widgets/chat_input_field.dart';

/// Shared chat screen used by both User and Admin.
/// [isAdminView] controls the gradient/color theme and which side admin sees.
class ChatScreen extends StatefulWidget {
  final ComplaintModel complaint;
  final bool isAdminView;

  const ChatScreen({
    super.key,
    required this.complaint,
    this.isAdminView = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
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
    final complaint = widget.complaint;
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser!;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
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
              widget.isAdminView
                  ? '${complaint.userName} · ${complaint.unit}'
                  : complaint.category,
              style: AppTextStyles.caption(
                      color: Colors.white.withOpacity(0.8))
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
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
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
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 48, color: _primary.withOpacity(0.3)),
                        const SizedBox(height: 12),
                        Text('No messages yet',
                            style: AppTextStyles.bodyMedium(
                                color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text('Start the conversation below',
                            style: AppTextStyles.caption()),
                      ],
                    ),
                  );
                }

                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final showDate = index == 0 ||
                        !_isSameDay(
                            messages[index - 1].timestamp, msg.timestamp);

                    return Column(
                      children: [
                        if (showDate)
                          ChatDateSeparator(date: msg.timestamp),
                        ChatBubble(
                          content: msg.content,
                          senderName: msg.senderName,
                          timestamp: msg.timestamp,
                          isFromAdmin: msg.isFromAdmin,
                          showSenderName: widget.isAdminView && msg.isFromAdmin == false,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Input field
          if (complaint.status != ComplaintStatus.resolved)
            ChatInputField(
              sendGradient: _gradient,
              onSend: (text) async {
                await context.read<ComplaintProvider>().sendMessage(
                      complaintId: complaint.id,
                      senderId: user.id,
                      senderName: user.name,
                      isFromAdmin: widget.isAdminView,
                      content: text,
                    );
                _scrollToBottom();
              },
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              color: AppColors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.paid, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'This complaint has been resolved',
                    style:
                        AppTextStyles.caption(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _showStatusSheet() {
    final statuses = [
      ComplaintStatus.open,
      ComplaintStatus.inProgress,
      ComplaintStatus.resolved,
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => BottomSheetContainer(
        title: 'Update Status',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: statuses.map((s) {
            final isCurrent = widget.complaint.status == s;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                _statusIcon(s),
                color: _statusColor(s),
              ),
              title: Text(s,
                  style: AppTextStyles.bodyMedium(color: AppColors.textPrimary)
                      .copyWith(
                          fontWeight: isCurrent
                              ? FontWeight.w700
                              : FontWeight.w400)),
              trailing: isCurrent
                  ? const Icon(Icons.check_rounded, color: AppColors.green)
                  : null,
              onTap: () async {
                Navigator.pop(context);
                await context
                    .read<ComplaintProvider>()
                    .updateStatus(widget.complaint.id, s);
                setState(() {});
              },
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
        return AppColors.blue;
      case ComplaintStatus.resolved:
        return AppColors.paid;
      default:
        return AppColors.textSecondary;
    }
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
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.4)),
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
