import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../models/app_version_model.dart';
import '../../../models/update_status.dart';
import '../../utils/app_utils.dart';
import '../../utils/version_compare.dart';
import '../firestore_service.dart';

/// Fetches version info from Firestore (`systemConfig/versionConfig`).
///
/// Firestore document fields:
///   latestVersion : "1.0.6"
///   forceUpdate   : false
///   playStoreUrl  : ""   (optional — package ID is used directly)
///
/// Fallback chain:
///   1. Firestore live fetch (requires signed-in user).
///   2. Hive persistent cache (populated on every successful fetch).
///   3. Safe default (0.0.0 — never triggers an update prompt).
class VersionService {
  static const String _hiveVersionKey = 'rc_latest_version';
  static const String _hiveForcedKey  = 'rc_force_update';

  /// Fetches the latest version info. Never throws — always returns a model.
  Future<AppVersionModel> fetchVersionInfo() async {
    // ── 1. Firestore live fetch ───────────────────────────────────────────────
    try {
      final config = await FirestoreService().getVersionConfig();
      if (config != null) {
        final model = AppVersionModel.fromMap(config);
        if (model.latestVersion.isNotEmpty && model.latestVersion != '0.0.0') {
          debugPrint('[VersionService] Firestore versionConfig: ${model.latestVersion} force=${model.forceUpdate}');
          // Persist to Hive for future launches.
          final box = Hive.box<String>('session');
          await box.put(_hiveVersionKey, model.latestVersion);
          await box.put(_hiveForcedKey,  model.forceUpdate.toString());
          return model;
        }
        debugPrint('[VersionService] Firestore versionConfig latestVersion is empty/0.0.0 — skipping');
      } else {
        debugPrint('[VersionService] Firestore versionConfig document does NOT exist.');
        debugPrint('[VersionService]   Path: systemConfig/versionConfig');
        debugPrint('[VersionService]   Fields: { latestVersion: "1.0.6", forceUpdate: false }');
      }
    } catch (e) {
      debugPrint('[VersionService] Firestore fetch error: $e');
    }

    // ── 2. Hive persistent cache ──────────────────────────────────────────────
    final box = Hive.box<String>('session');
    final cachedVersion = box.get(_hiveVersionKey);
    if (cachedVersion != null && cachedVersion != '0.0.0') {
      final cachedForce = box.get(_hiveForcedKey) == 'true';
      debugPrint('[VersionService] Using Hive cache: $cachedVersion force=$cachedForce');
      return AppVersionModel(
        latestVersion: cachedVersion,
        forceUpdate:   cachedForce,
        playStoreUrl:  '',
      );
    }

    debugPrint('[VersionService] No version data available — defaulting to upToDate.');
    return AppVersionModel.empty;
  }

  /// Compares the installed version against [model.latestVersion].
  Future<UpdateStatus> determineUpdateStatus(AppVersionModel model) async {
    final packageInfo = await PackageInfo.fromPlatform();
    final installed   = packageInfo.version;
    debugPrint('[VersionService] installed=$installed  latest=${model.latestVersion}  force=${model.forceUpdate}');
    if (VersionCompare.isLessThan(installed, model.latestVersion)) {
      return model.forceUpdate ? UpdateStatus.forceUpdate : UpdateStatus.optionalUpdate;
    }
    return UpdateStatus.upToDate;
  }

  static const String _packageId = 'com.maintify.app';

  /// Opens the Play Store (or App Store on iOS).
  Future<void> openStore(AppVersionModel model) async {
    debugPrint('[VersionService] Opening store for $_packageId');
    await AppUtils.launchPlayStore(_packageId);
  }
}
