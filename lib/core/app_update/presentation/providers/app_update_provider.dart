import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../domain/entities/app_update_info.dart';
import '../../domain/entities/app_update_progress.dart';
import '../../domain/repositories/app_update_repository.dart';

class AppUpdateProvider extends ChangeNotifier {
  AppUpdateInfo _info = AppUpdateInfo.upToDate;
  AppUpdateProgress _progress = AppUpdateProgress.idle;
  bool _isChecking = false;
  String? _error;

  AppUpdateInfo get info => _info;
  AppUpdateProgress get progress => _progress;
  bool get isChecking => _isChecking;
  String? get error => _error;

  /// Exposes the raw progress stream from the repository for widgets that
  /// need live byte-level updates (e.g. progress dialogs).
  Stream<AppUpdateProgress> get progressStream => _repository.progressStream;

  final AppUpdateRepository _repository;
  StreamSubscription<AppUpdateProgress>? _progressSub;

  AppUpdateProvider(this._repository);

  /// Checks for an available update via Google Play Core.
  Future<void> checkForUpdate() async {
    if (_isChecking) return;
    _isChecking = true;
    _error = null;
    notifyListeners();

    try {
      final info = await _repository.checkForUpdate();
      _info = info;
      debugPrint(
        '[AppUpdateProvider] checkForUpdate → status=${info.status} mode=${info.mode}',
      );
    } catch (e) {
      _error = e.toString();
      debugPrint('[AppUpdateProvider] checkForUpdate error: $e');
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  /// Starts a flexible (background) update download and subscribes to
  /// progress events.
  Future<void> startFlexibleUpdate() async {
    _error = null;
    _progress = AppUpdateProgress.idle;
    notifyListeners();

    // Subscribe to progress stream before starting so we don't miss events.
    _progressSub?.cancel();
    _progressSub = _repository.progressStream.listen(
      (p) {
        _progress = p;
        notifyListeners();
      },
      onError: (Object e) {
        _error = e.toString();
        _progress = const AppUpdateProgress(
          status: DownloadStatus.failed,
          progress: 0.0,
        );
        notifyListeners();
      },
    );

    try {
      await _repository.startFlexibleUpdate();
    } catch (e) {
      _error = e.toString();
      _progress = const AppUpdateProgress(
        status: DownloadStatus.failed,
        progress: 0.0,
      );
      notifyListeners();
    }
  }

  /// Triggers installation of a fully downloaded flexible update.
  Future<void> completeUpdate() async {
    try {
      await _repository.completeFlexibleUpdate();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Launches the full-screen Play Store immediate update flow.
  Future<void> performImmediateUpdate() async {
    _error = null;
    notifyListeners();
    try {
      await _repository.performImmediateUpdate();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ── Dismissal persistence (Hive 'session' box) ────────────────────────────

  /// Marks [version] as dismissed so the optional update dialog is not shown
  /// again for this version. Uses the same Hive 'session' box as AuthProvider.
  void dismissUpdate(String? version) {
    if (version == null) return;
    try {
      final box = Hive.box<String>('session');
      box.put('app_update_dismissed_$version', 'true');
    } catch (e) {
      debugPrint('[AppUpdateProvider] dismissUpdate error (non-critical): $e');
    }
  }

  /// Returns true if the user has previously dismissed the update dialog for
  /// [version].
  bool isDismissed(String? version) {
    if (version == null) return false;
    try {
      final box = Hive.box<String>('session');
      return box.get('app_update_dismissed_$version') == 'true';
    } catch (e) {
      return false;
    }
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    super.dispose();
  }
}
