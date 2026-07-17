import 'package:flutter/material.dart';
import '../core/theme/app_text_styles.dart';

/// Reusable bottom sheet wrapper.
/// Provides drag handle, rounded top corners, header with optional close button,
/// and consistent padding. Use inside showModalBottomSheet.
class BottomSheetContainer extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? headerTrailing;
  final double? minHeight;
  final bool showDragHandle;
  final EdgeInsetsGeometry contentPadding;

  const BottomSheetContainer({
    super.key,
    required this.title,
    required this.child,
    this.headerTrailing,
    this.minHeight,
    this.showDragHandle = true,
    this.contentPadding = const EdgeInsets.fromLTRB(20, 0, 20, 20),
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          if (showDragHandle)
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

          // Header
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              showDragHandle ? 8 : 20,
              12,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.heading3(color: cs.onSurface),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                headerTrailing ??
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: cs.onSurfaceVariant),
                      onPressed: () => Navigator.pop(context),
                    ),
              ],
            ),
          ),

          Divider(height: 16, color: cs.outline.withOpacity(0.3)),

          // Content
          Padding(
            padding: contentPadding,
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Scrollable variant — wraps content in a SingleChildScrollView.
class ScrollableBottomSheet extends StatelessWidget {
  final String title;
  final Widget child;
  final bool showDragHandle;

  const ScrollableBottomSheet({
    super.key,
    required this.title,
    required this.child,
    this.showDragHandle = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              if (showDragHandle)
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                    20, showDragHandle ? 8 : 20, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(title,
                          style: AppTextStyles.heading3(color: cs.onSurface),
                          overflow: TextOverflow.ellipsis),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: cs.onSurfaceVariant),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Divider(height: 16, color: cs.outline.withOpacity(0.3)),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: child,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
