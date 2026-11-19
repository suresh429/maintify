import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/app_version_model.dart';
import '../core/theme/app_colors.dart';

/// Shows a Material 3 update dialog.
///
/// **Force update** ([isForce] = true)
///   - Non-dismissible barrier, back button trapped via [PopScope].
///   - Single "Update Now" button — tapping opens the store but does NOT
///     close the dialog. The user cannot bypass it.
///
/// **Optional update** ([isForce] = false)
///   - "Later" dismisses. "Update Now" opens the store and dismisses.
Future<void> showUpdateDialog(
  BuildContext context, {
  required AppVersionModel model,
  required bool isForce,
  required VoidCallback onUpdate,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (_) => _UpdateDialog(
      model: model,
      isForce: isForce,
      onUpdate: onUpdate,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({
    required this.model,
    required this.isForce,
    required this.onUpdate,
  });

  final AppVersionModel model;
  final bool isForce;
  final VoidCallback onUpdate;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleUpdate() {
    widget.onUpdate();
    // Optional update: close dialog after opening store.
    // Force update: dialog stays — user cannot proceed without updating.
    if (!widget.isForce && mounted) Navigator.of(context).pop();
  }

  void _handleLater() {
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Trap the hardware back button for force updates.
      canPop: !widget.isForce,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: _DialogContent(
              model: widget.model,
              isForce: widget.isForce,
              onUpdate: _handleUpdate,
              onLater: _handleLater,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _DialogContent extends StatelessWidget {
  const _DialogContent({
    required this.model,
    required this.isForce,
    required this.onUpdate,
    required this.onLater,
  });

  final AppVersionModel model;
  final bool isForce;
  final VoidCallback onUpdate;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final surface  = isDark ? AppColors.darkSurface : Colors.white;
    final onSurface = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final subtle   = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Material(
        color: surface,
        elevation: 12,
        shadowColor: Colors.black26,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.system_update_outlined,
                  size: 32,
                  color: isForce ? const Color(0xFFDC2626) : const Color(0xFF1E3A8A),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                'Update Available',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: onSurface,
                ),
              ),
              const SizedBox(height: 6),

              // Subtitle
              Text(
                isForce
                    ? 'A required update (v${model.latestVersion}) is available. Please update to continue.'
                    : 'A new version (v${model.latestVersion}) is available.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: subtle,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  if (!isForce) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onLater,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          side: BorderSide(
                            color: isDark
                                ? AppColors.darkBorder
                                : const Color(0xFFCBD5E1),
                          ),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Later',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: subtle,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: isForce ? 1 : 2,
                    child: ElevatedButton(
                      onPressed: onUpdate,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        backgroundColor: isForce
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Update',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
