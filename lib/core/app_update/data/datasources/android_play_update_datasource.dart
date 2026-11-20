import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart' as play;

import '../../domain/entities/app_update_info.dart';
import '../../domain/entities/app_update_progress.dart';

/// Wraps the `in_app_update` package (Google Play Core API).
///
/// Priority rules (mirrors Play Console recommendations):
///   priority 5 OR stalenessDays > 90  → immediate (force)
///   priority >= 3 OR stalenessDays > 30 → flexible optional
///   otherwise                           → flexible optional
class AndroidPlayUpdateDatasource {
  final _progressController =
      StreamController<AppUpdateProgress>.broadcast();

  Stream<AppUpdateProgress> get progressStream => _progressController.stream;

  Future<AppUpdateInfo> checkForUpdate() async {
    final info = await play.InAppUpdate.checkForUpdate();
    debugPrint(
      '[AppUpdate] availability=${info.updateAvailability} '
      'priority=${info.updatePriority} '
      'stalenessDays=${info.clientVersionStalenessDays} '
      'immediate=${info.immediateUpdateAllowed} '
      'flexible=${info.flexibleUpdateAllowed}',
    );

    if (info.updateAvailability != play.UpdateAvailability.updateAvailable) {
      return AppUpdateInfo.upToDate;
    }

    final priority = info.updatePriority;
    final staleness = info.clientVersionStalenessDays ?? 0;
    final versionCode = info.availableVersionCode;

    // Determine mode based on priority + staleness
    final bool shouldForce =
        (priority == 5 || staleness > 90) && info.immediateUpdateAllowed;

    if (shouldForce) {
      return AppUpdateInfo(
        status: AppUpdateStatus.forceUpdate,
        mode: AppUpdateMode.immediate,
        priority: priority,
        stalenessDays: staleness,
        availableVersionCode: versionCode,
      );
    }

    // Optional flexible update
    if (info.flexibleUpdateAllowed) {
      return AppUpdateInfo(
        status: AppUpdateStatus.optionalUpdate,
        mode: AppUpdateMode.flexible,
        priority: priority,
        stalenessDays: staleness,
        availableVersionCode: versionCode,
      );
    }

    // Update available but flexible not allowed — try immediate as optional.
    if (info.immediateUpdateAllowed) {
      return AppUpdateInfo(
        status: AppUpdateStatus.optionalUpdate,
        mode: AppUpdateMode.immediate,
        priority: priority,
        stalenessDays: staleness,
        availableVersionCode: versionCode,
      );
    }

    return AppUpdateInfo.upToDate;
  }

  Future<void> startFlexibleUpdate() async {
    _progressController.add(const AppUpdateProgress(
      status: DownloadStatus.downloading,
      progress: 0.0,
    ));

    // Listen to the install-status event stream from the Play Core library.
    // The stream emits InstallStatus values (not bytes), so we report
    // indeterminate progress (0.0) while downloading.
    play.InAppUpdate.installUpdateListener.listen(
      (status) {
        final progress = _mapInstallStatus(status);
        _progressController.add(progress);
      },
      onError: (Object error) {
        debugPrint('[AppUpdate] installUpdateListener error: $error');
        _progressController.add(const AppUpdateProgress(
          status: DownloadStatus.failed,
          progress: 0.0,
        ));
      },
    );

    final result = await play.InAppUpdate.startFlexibleUpdate();
    debugPrint('[AppUpdate] startFlexibleUpdate result: $result');

    if (result != play.AppUpdateResult.success) {
      _progressController.add(const AppUpdateProgress(
        status: DownloadStatus.failed,
        progress: 0.0,
      ));
    }
  }

  Future<void> completeFlexibleUpdate() async {
    _progressController.add(const AppUpdateProgress(
      status: DownloadStatus.installing,
      progress: 1.0,
    ));
    await play.InAppUpdate.completeFlexibleUpdate();
    _progressController.add(const AppUpdateProgress(
      status: DownloadStatus.installed,
      progress: 1.0,
    ));
  }

  Future<void> performImmediateUpdate() async {
    final result = await play.InAppUpdate.performImmediateUpdate();
    debugPrint('[AppUpdate] performImmediateUpdate result: $result');
  }

  AppUpdateProgress _mapInstallStatus(play.InstallStatus status) {
    switch (status) {
      case play.InstallStatus.downloading:
        // Play Core's status-only stream doesn't carry byte counts;
        // report indeterminate progress until downloaded.
        return const AppUpdateProgress(
          status: DownloadStatus.downloading,
          progress: 0.0,
        );
      case play.InstallStatus.downloaded:
        return const AppUpdateProgress(
          status: DownloadStatus.downloaded,
          progress: 1.0,
        );
      case play.InstallStatus.installing:
        return const AppUpdateProgress(
          status: DownloadStatus.installing,
          progress: 1.0,
        );
      case play.InstallStatus.installed:
        return const AppUpdateProgress(
          status: DownloadStatus.installed,
          progress: 1.0,
        );
      case play.InstallStatus.failed:
        return const AppUpdateProgress(
          status: DownloadStatus.failed,
          progress: 0.0,
        );
      case play.InstallStatus.canceled:
        return const AppUpdateProgress(
          status: DownloadStatus.canceled,
          progress: 0.0,
        );
      default:
        return AppUpdateProgress.idle;
    }
  }

  void dispose() {
    _progressController.close();
  }
}
