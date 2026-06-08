import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Bottom-anchored chat input bar.
/// Shows a rounded text field with a send button.
/// [onSend] is called with the trimmed message text.
class ChatInputField extends StatefulWidget {
  final void Function(String message) onSend;
  final String hint;
  final List<Color> sendGradient;

  const ChatInputField({
    super.key,
    required this.onSend,
    this.hint = 'Type a message...',
    this.sendGradient = AppColors.adminGradient,
  });

  @override
  State<ChatInputField> createState() => _ChatInputFieldState();
}

class _ChatInputFieldState extends State<ChatInputField> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    setState(() => _hasText = false);
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, MediaQuery.of(context).viewInsets.bottom + 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Text field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.lightGray,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Send button
          GestureDetector(
            onTap: _hasText ? _send : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: _hasText
                    ? LinearGradient(
                        colors: widget.sendGradient,
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      )
                    : null,
                color: _hasText ? null : Colors.grey.shade200,
                shape: BoxShape.circle,
                boxShadow: _hasText
                    ? [
                        BoxShadow(
                          color: widget.sendGradient.first.withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : null,
              ),
              child: Icon(
                Icons.send_rounded,
                color: _hasText ? Colors.white : Colors.grey.shade400,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
