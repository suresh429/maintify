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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : Colors.white;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final divider = isDark ? AppColors.darkBorder : const Color(0xFFE8EDF2);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Material(
        color: surface,
        elevation: 16,
        shadowColor: Colors.black26,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ───────────────────────────────────────────────────────
            _Header(isForce: isForce),

            // ── Body ─────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Update Available',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'A newer version of Maintify (v${model.latestVersion}) is available.\n\n'
                    'Please update the app to enjoy the latest features, '
                    'performance improvements, bug fixes, and security enhancements.',
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                      color: textSecondary,
                      height: 1.6,
                    ),
                  ),
                  if (isForce) ...[
                    const SizedBox(height: 14),
                    _ForceNote(isDark: isDark),
                  ],
                ],
              ),
            ),

            // ── Buttons ──────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: surface,
                border: Border(top: BorderSide(color: divider)),
              ),
              child: isForce
                  ? _UpdateButton(onTap: onUpdate, isForce: true)
                  : Row(
                      children: [
                        Expanded(
                          child: _LaterButton(
                              onTap: onLater, isDark: isDark),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: _UpdateButton(
                              onTap: onUpdate, isForce: false),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.isForce});

  final bool isForce;

  static const _blueGradient = [Color(0xFF3B82F6), Color(0xFF1D4ED8)];
  static const _redGradient = [Color(0xFFEF4444), Color(0xFFB91C1C)];

  @override
  Widget build(BuildContext context) {
    final gradient = isForce ? _redGradient : _blueGradient;

    return Container(
      width: double.infinity,
      height: 118,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
      ),
      child: Stack(
        children: [
          // Decorative circle — top right
          Positioned(
            top: -18,
            right: -18,
            child: _Circle(size: 90, opacity: 0.08),
          ),
          // Decorative circle — bottom left
          Positioned(
            bottom: -24,
            left: -8,
            child: _Circle(size: 72, opacity: 0.06),
          ),
          // Icon centred
          Center(
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isForce
                    ? Icons.system_update_rounded
                    : Icons.system_update_alt_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Small warning banner shown below the body text for force updates.
class _ForceNote extends StatelessWidget {
  const _ForceNote({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 16, color: Color(0xFFDC2626)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'This update is required to continue using Maintify.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFDC2626),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _UpdateButton extends StatelessWidget {
  const _UpdateButton({required this.onTap, required this.isForce});

  final VoidCallback onTap;
  final bool isForce;

  @override
  Widget build(BuildContext context) {
    final colors = isForce
        ? const [Color(0xFFEF4444), Color(0xFFB91C1C)]
        : const [Color(0xFF3B82F6), Color(0xFF1D4ED8)];

    return SizedBox(
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: colors.last.withOpacity(0.28),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.system_update_rounded,
                  color: Colors.white, size: 17),
              const SizedBox(width: 6),
              Text(
                'Update Now',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LaterButton extends StatelessWidget {
  const _LaterButton({required this.onTap, required this.isDark});

  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: isDark ? AppColors.darkBorder : const Color(0xFFCBD5E1),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          'Later',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
