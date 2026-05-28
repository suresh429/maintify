import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/app_utils.dart';

/// A single chat message bubble.
/// [isFromAdmin] — determines alignment (true = left/blue, false = right/green).
class ChatBubble extends StatelessWidget {
  final String content;
  final String senderName;
  final DateTime timestamp;
  final bool isFromAdmin;
  final bool showSenderName;

  const ChatBubble({
    super.key,
    required this.content,
    required this.senderName,
    required this.timestamp,
    required this.isFromAdmin,
    this.showSenderName = false,
  });

  @override
  Widget build(BuildContext context) {
    final isLeft = isFromAdmin;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isLeft) ...[
            _Avatar(name: senderName, isAdmin: true),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.70,
              ),
              child: Column(
                crossAxisAlignment: isLeft
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.end,
                children: [
                  if (showSenderName)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3, left: 2, right: 2),
                      child: Text(
                        senderName,
                        style: AppTextStyles.caption(
                          color: isLeft ? AppColors.blue : AppColors.green,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isLeft
                          ? AppColors.blue.withOpacity(0.08)
                          : AppColors.green.withOpacity(0.12),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isLeft ? 4 : 18),
                        bottomRight: Radius.circular(isLeft ? 18 : 4),
                      ),
                      border: Border.all(
                        color: isLeft
                            ? AppColors.blue.withOpacity(0.15)
                            : AppColors.green.withOpacity(0.25),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      content,
                      style: AppTextStyles.bodyMedium(
                              color: AppColors.textPrimary)
                          .copyWith(height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      _formatTime(timestamp),
                      style: AppTextStyles.caption(
                              color: AppColors.textSecondary)
                          .copyWith(fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isLeft) ...[
            const SizedBox(width: 8),
            _Avatar(name: senderName, isAdmin: false),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    return AppUtils.timeAgo(dt);
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final bool isAdmin;

  const _Avatar({required this.name, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final initials = name
        .split(' ')
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0].toUpperCase())
        .join();

    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: isAdmin
            ? AppColors.blue.withOpacity(0.15)
            : AppColors.green.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isAdmin ? AppColors.blue : AppColors.green,
          ),
        ),
      ),
    );
  }
}

/// A date separator row shown between messages from different days.
class ChatDateSeparator extends StatelessWidget {
  final DateTime date;

  const ChatDateSeparator({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(msgDay).inDays;

    String label;
    if (diff == 0) {
      label = 'Today';
    } else if (diff == 1) {
      label = 'Yesterday';
    } else {
      label = AppUtils.formatDate(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: AppTextStyles.caption(color: AppColors.textSecondary),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}
