import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/entities/app_update_info.dart';
import '../../domain/entities/app_update_progress.dart';
import '../providers/app_update_provider.dart';
import '../widgets/update_dialogs.dart';

/// Orchestrates the full in-app update flow for Android.
///
/// Usage — call [runUpdateCheck] from [DashboardRouter] after login
/// (typically with a 3-second delay to let the dashboard settle).
class AppUpdateCoordinator {
  final AppUpdateProvider provider;

  AppUpdateCoordinator(this.provider);

  /// Entry point. Checks for an update and drives the appropriate UI flow.
  Future<void> runUpdateCheck(BuildContext context) async {
    debugPrint('[AppUpdateCoordinator] Starting update check…');
    await provider.checkForUpdate();

    if (!context.mounted) return;

    final info = provider.info;
    debugPrint(
      '[AppUpdateCoordinator] status=${info.status} mode=${info.mode}',
    );

    if (info.status == AppUpdateStatus.upToDate) return;
    if (info.status == AppUpdateStatus.unknown) return;

    if (info.mode == AppUpdateMode.flexible) {
      await _handleFlexibleUpdate(context, info);
    } else if (info.mode == AppUpdateMode.immediate) {
      await _handleImmediateUpdate(context, info);
    }
  }

  // ── Flexible update flow ────────────────────────────────────────────────────

  Future<void> _handleFlexibleUpdate(
    BuildContext context,
    AppUpdateInfo info,
  ) async {
    // 1. Ask the user if they want to update now.
    final shouldUpdate = await _showOptionalDialog(context, info);
    if (!shouldUpdate) {
      debugPrint('[AppUpdateCoordinator] User dismissed optional update.');
      return;
    }
    if (!context.mounted) return;

    // 2. Start the background download.
    debugPrint('[AppUpdateCoordinator] Starting flexible update download…');
    await provider.startFlexibleUpdate();
    if (!context.mounted) return;

    // 3. Show progress dialog — it auto-dismisses when download completes.
    _listenAndShowProgress(context);
  }

  // ── Immediate update flow ───────────────────────────────────────────────────

  Future<void> _handleImmediateUpdate(
    BuildContext context,
    AppUpdateInfo info,
  ) async {
    debugPrint('[AppUpdateCoordinator] Starting immediate update…');
    // Show the critical dialog (non-dismissible) while Play Core takes over.
    _showCriticalDialog(context, info);
    await provider.performImmediateUpdate();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Future<bool> _showOptionalDialog(
    BuildContext context,
    AppUpdateInfo info,
  ) async {
    // Check if the user has already dismissed this version.
    final versionKey = info.availableVersionCode?.toString();
    if (provider.isDismissed(versionKey)) {
      debugPrint('[AppUpdateCoordinator] Update dismissed for version $versionKey');
      return false;
    }

    if (!context.mounted) return false;

    final shouldUpdate = await showMaintifyUpdateDialog(
      context,
      info,
      () {}, // onUpdate handled by return value
      () => provider.dismissUpdate(versionKey),
    );

    if (!shouldUpdate) {
      provider.dismissUpdate(versionKey);
    }

    return shouldUpdate;
  }

  void _showCriticalDialog(BuildContext context, AppUpdateInfo info) {
    if (!context.mounted) return;
    showMaintifyCriticalUpdateDialog(
      context,
      info,
      () {
        debugPrint('[AppUpdateCoordinator] Critical update — user tapped Update Now');
        provider.performImmediateUpdate();
      },
    );
  }

  void _listenAndShowProgress(BuildContext context) {
    if (!context.mounted) return;

    // Show the progress dialog tracking the download stream.
    final UpdateProgressDialogController dialogController =
        showMaintifyUpdateProgressDialog(
      context,
      provider.progressStream,
    );

    // Subscribe to the progress stream to react to terminal states.
    StreamSubscription<AppUpdateProgress>? sub;
    sub = provider.progressStream.listen((progress) async {
      if (progress.status == DownloadStatus.failed) {
        sub?.cancel();
        dialogController.dismiss();
        if (context.mounted) {
          await showMaintifyUpdateErrorDialog(
            context,
            provider.error ?? 'Update download failed.',
            () => runUpdateCheck(context),
          );
        }
        return;
      }

      if (progress.status == DownloadStatus.downloaded) {
        sub?.cancel();
        // Progress dialog auto-dismisses after a short delay (see _ProgressDialog).
        // Wait briefly before showing the install-ready sheet.
        await Future.delayed(const Duration(milliseconds: 600));
        if (!context.mounted) return;

        await showMaintifyUpdateReadyDialog(
          context,
          () async {
            debugPrint('[AppUpdateCoordinator] User tapped Install Now');
            await provider.completeUpdate();
          },
        );
      }
    });
  }
}
