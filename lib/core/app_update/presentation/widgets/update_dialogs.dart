import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/app_update_info.dart';
import '../../domain/entities/app_update_progress.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 1. Optional update bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

/// Shows an optional update bottom sheet.
/// Returns `true` if the user tapped "Update Now", `false` otherwise.
Future<bool> showMaintifyUpdateDialog(
  BuildContext context,
  AppUpdateInfo info,
  VoidCallback onUpdate,
  VoidCallback onLater,
) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    enableDrag: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _UpdateBottomSheet(
        info: info,
        isForce: false,
        onUpdate: onUpdate,
        onLater: onLater,
      ),
    ),
  );
  return result ?? false;
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Force/critical update bottom sheet (non-dismissible)
// ─────────────────────────────────────────────────────────────────────────────

/// Shows a critical (force) update bottom sheet with no dismiss option.
void showMaintifyCriticalUpdateDialog(
  BuildContext context,
  AppUpdateInfo info,
  VoidCallback onUpdate,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: PopScope(
        canPop: false,
        child: _UpdateBottomSheet(
          info: info,
          isForce: true,
          onUpdate: onUpdate,
          onLater: () {}, // unused for force
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. Download progress dialog
// ─────────────────────────────────────────────────────────────────────────────

/// Controller returned by [showMaintifyUpdateProgressDialog] that allows the
/// caller to dismiss the progress dialog programmatically.
class UpdateProgressDialogController {
  VoidCallback? _dismiss;

  void dismiss() => _dismiss?.call();
}

/// Shows a non-dismissible progress dialog that tracks the flexible download.
/// Auto-dismisses when the status reaches [DownloadStatus.downloaded] or
/// [DownloadStatus.installed].
///
/// Returns an [UpdateProgressDialogController] that can be used to dismiss
/// the dialog programmatically.
UpdateProgressDialogController showMaintifyUpdateProgressDialog(
  BuildContext context,
  Stream<AppUpdateProgress> progressStream,
) {
  final controller = UpdateProgressDialogController();

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (dialogContext) {
      controller._dismiss = () {
        if (dialogContext.mounted) Navigator.of(dialogContext).pop();
      };
      return _ProgressDialog(
        progressStream: progressStream,
        onAutoDismiss: controller._dismiss,
      );
    },
  );

  return controller;
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. Update ready (downloaded) dialog
// ─────────────────────────────────────────────────────────────────────────────

/// Shows a bottom sheet when the flexible update has been downloaded and is
/// ready to install. Returns `true` if the user tapped "Install Now".
Future<bool> showMaintifyUpdateReadyDialog(
  BuildContext context,
  VoidCallback onInstall,
) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    enableDrag: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _UpdateReadySheet(onInstall: onInstall),
    ),
  );
  return result ?? false;
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. Error dialog
// ─────────────────────────────────────────────────────────────────────────────

/// Shows an error bottom sheet with a Retry button.
Future<void> showMaintifyUpdateErrorDialog(
  BuildContext context,
  String error,
  VoidCallback onRetry,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    enableDrag: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _UpdateErrorSheet(error: error, onRetry: onRetry),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Private widgets
// ─────────────────────────────────────────────────────────────────────────────

class _UpdateBottomSheet extends StatelessWidget {
  final AppUpdateInfo info;
  final bool isForce;
  final VoidCallback onUpdate;
  final VoidCallback onLater;

  const _UpdateBottomSheet({
    required this.info,
    required this.isForce,
    required this.onUpdate,
    required this.onLater,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : AppColors.white;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final borderColor =
        isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkBorder
                  : const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (isForce
                      ? const Color(0xFFEF4444)
                      : AppColors.blue)
                  .withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isForce
                  ? Icons.security_update_warning_outlined
                  : Icons.system_update_outlined,
              size: 36,
              color: isForce ? const Color(0xFFEF4444) : AppColors.blue,
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            isForce ? 'Critical Update Required' : 'Update Available',
            style: AppTextStyles.heading3(color: textPrimary),
          ),
          const SizedBox(height: 8),

          // Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              isForce
                  ? 'A critical update is required to continue using Maintify. Please update now.'
                  : 'A new version of Maintify is available with improvements and bug fixes.',
              style: AppTextStyles.bodyMedium(color: textSecondary),
              textAlign: TextAlign.center,
            ),
          ),

          if (info.stalenessDays != null && info.stalenessDays! > 0) ...[
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: (isForce
                        ? const Color(0xFFEF4444)
                        : AppColors.pending)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Update available for ${info.stalenessDays} day${info.stalenessDays! != 1 ? 's' : ''}',
                style: AppTextStyles.caption(
                  color: isForce
                      ? const Color(0xFFEF4444)
                      : AppColors.pending,
                ),
              ),
            ),
          ],

          const SizedBox(height: 28),

          // Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                if (!isForce) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop(false);
                        onLater();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: borderColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Later',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: isForce ? 1 : 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isForce
                            ? [
                                const Color(0xFFEF4444),
                                const Color(0xFFDC2626),
                              ]
                            : AppColors.adminGradient,
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        if (!isForce) Navigator.of(context).pop(true);
                        onUpdate();
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Update Now',
                        style: AppTextStyles.buttonText(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          // Safe-area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ProgressDialog extends StatefulWidget {
  final Stream<AppUpdateProgress> progressStream;
  final VoidCallback? onAutoDismiss;

  const _ProgressDialog({required this.progressStream, this.onAutoDismiss});

  @override
  State<_ProgressDialog> createState() => _ProgressDialogState();
}

class _ProgressDialogState extends State<_ProgressDialog> {
  StreamSubscription<AppUpdateProgress>? _sub;
  AppUpdateProgress _current = AppUpdateProgress.idle;

  @override
  void initState() {
    super.initState();
    _sub = widget.progressStream.listen((p) {
      if (!mounted) return;
      setState(() => _current = p);
      if (p.status == DownloadStatus.downloaded ||
          p.status == DownloadStatus.installed) {
        Future.delayed(const Duration(milliseconds: 400), () {
          widget.onAutoDismiss?.call();
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String get _statusLabel {
    switch (_current.status) {
      case DownloadStatus.downloading:
        final pct = (_current.progress * 100).toStringAsFixed(0);
        return 'Downloading update… $pct%';
      case DownloadStatus.downloaded:
        return 'Download complete!';
      case DownloadStatus.installing:
        return 'Installing update…';
      case DownloadStatus.installed:
        return 'Update installed!';
      case DownloadStatus.failed:
        return 'Download failed';
      case DownloadStatus.canceled:
        return 'Download canceled';
      default:
        return 'Preparing download…';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : AppColors.white;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: _current.status == DownloadStatus.downloading
                        ? _current.progress
                        : null,
                    strokeWidth: 3,
                    color: AppColors.blue,
                    backgroundColor:
                        isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                  ),
                  Icon(
                    Icons.system_update_outlined,
                    size: 24,
                    color: AppColors.blue,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _statusLabel,
              style: AppTextStyles.subheading(color: textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Please keep the app open.',
              style: AppTextStyles.bodySmall(color: textSecondary),
              textAlign: TextAlign.center,
            ),
            if (_current.status == DownloadStatus.downloading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _current.progress,
                backgroundColor:
                    isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                color: AppColors.blue,
                borderRadius: BorderRadius.circular(4),
                minHeight: 6,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _UpdateReadySheet extends StatelessWidget {
  final VoidCallback onInstall;

  const _UpdateReadySheet({required this.onInstall});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : AppColors.white;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final borderColor =
        isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkBorder
                  : const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Success icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.paid.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline,
              size: 36,
              color: AppColors.paid,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Update Ready!',
            style: AppTextStyles.heading3(color: textPrimary),
          ),
          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'The update has been downloaded and is ready to install. The app will restart.',
              style: AppTextStyles.bodyMedium(color: textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 28),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: borderColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Later',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppColors.adminGradient,
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(true);
                        onInstall();
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Install Now',
                        style: AppTextStyles.buttonText(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _UpdateErrorSheet extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _UpdateErrorSheet({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : AppColors.white;
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkBorder
                  : const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.overdue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline,
              size: 36,
              color: AppColors.overdue,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Update Failed',
            style: AppTextStyles.heading3(color: textPrimary),
          ),
          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Something went wrong while updating. Please try again.',
              style: AppTextStyles.bodyMedium(color: textSecondary),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 28),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: isDark
                            ? AppColors.darkBorder
                            : const Color(0xFFE2E8F0),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Dismiss',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppColors.adminGradient,
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onRetry();
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Retry',
                        style: AppTextStyles.buttonText(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
