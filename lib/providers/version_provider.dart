import 'package:flutter/foundation.dart';

import '../models/app_version_model.dart';
import '../models/update_status.dart';
import '../core/services/version/version_service.dart';

/// Manages the version-check lifecycle and exposes [status] for the UI.
/// All business logic is delegated to [VersionService].
class VersionProvider extends ChangeNotifier {
  final _service = VersionService();

  AppVersionModel? _model;
  UpdateStatus _status = UpdateStatus.upToDate;
  bool _isChecking = false;

  AppVersionModel? get model => _model;
  UpdateStatus get status => _status;
  bool get isChecking => _isChecking;

  /// Fetches Remote Config and determines [UpdateStatus].
  /// On any failure the status falls back to [UpdateStatus.upToDate] so the
  /// app is never permanently blocked by a connectivity issue.
  Future<void> checkVersion() async {
    _isChecking = true;
    notifyListeners();

    try {
      _model = await _service.fetchVersionInfo();
      _status = await _service.determineUpdateStatus(_model!);
    } catch (e) {
      debugPrint('[VersionProvider] checkVersion error: $e');
      _status = UpdateStatus.upToDate;
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  /// Opens the Play Store URL stored in [model].
  Future<void> openStore() async {
    if (_model != null) await _service.openStore(_model!);
  }
}
