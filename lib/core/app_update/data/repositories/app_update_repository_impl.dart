import 'package:flutter/foundation.dart';

import '../../domain/entities/app_update_info.dart';
import '../../domain/entities/app_update_progress.dart';
import '../../domain/repositories/app_update_repository.dart';
import '../datasources/android_play_update_datasource.dart';

/// Implements [AppUpdateRepository].
///
/// On non-Android platforms or when running on the web, all calls are no-ops
/// and [checkForUpdate] immediately returns [AppUpdateInfo.upToDate].
///
/// In debug mode on Android, the Play Core API call is still attempted but
/// errors are caught and logged gracefully (Play Core requires the app to be
/// installed from the Play Store, so this is expected to fail in debug builds).
class AppUpdateRepositoryImpl implements AppUpdateRepository {
  final AndroidPlayUpdateDatasource _datasource;

  AppUpdateRepositoryImpl()
      : _datasource = AndroidPlayUpdateDatasource();

  /// Returns true when in-app update API calls should be attempted.
  bool get _isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<AppUpdateInfo> checkForUpdate() async {
    if (!_isSupported) return AppUpdateInfo.upToDate;

    try {
      return await _datasource.checkForUpdate();
    } catch (e) {
      // Expected in debug builds (not installed from Play Store).
      debugPrint('[AppUpdateRepository] checkForUpdate error (expected in debug): $e');
      return AppUpdateInfo.upToDate;
    }
  }

  @override
  Future<void> startFlexibleUpdate() async {
    if (!_isSupported) return;
    try {
      await _datasource.startFlexibleUpdate();
    } catch (e) {
      debugPrint('[AppUpdateRepository] startFlexibleUpdate error: $e');
      rethrow;
    }
  }

  @override
  Future<void> completeFlexibleUpdate() async {
    if (!_isSupported) return;
    try {
      await _datasource.completeFlexibleUpdate();
    } catch (e) {
      debugPrint('[AppUpdateRepository] completeFlexibleUpdate error: $e');
      rethrow;
    }
  }

  @override
  Future<void> performImmediateUpdate() async {
    if (!_isSupported) return;
    try {
      await _datasource.performImmediateUpdate();
    } catch (e) {
      debugPrint('[AppUpdateRepository] performImmediateUpdate error: $e');
      rethrow;
    }
  }

  @override
  Stream<AppUpdateProgress> get progressStream => _datasource.progressStream;
}
