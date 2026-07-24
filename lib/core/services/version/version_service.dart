import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/app_version_model.dart';
import '../../../models/update_status.dart';
import '../../utils/version_compare.dart';

/// Handles Remote Config fetching, version comparison, and Play Store
/// navigation. Contains zero UI code.
class VersionService {
  static const Duration _fetchTimeout = Duration(seconds: 8);

  /// Safe defaults so the app continues normally if Remote Config is
  /// unreachable on first launch (no cached values yet).
  static const Map<String, dynamic> _defaults = {
    'latest_version': '1.0.0',
    'force_update': false,
    'play_store_url': '',
  };

  /// Fetches and activates Remote Config, returning a typed [AppVersionModel].
  /// On network failure the previously cached (or default) values are used.
  Future<AppVersionModel> fetchVersionInfo() async {
    final rc = FirebaseRemoteConfig.instance;

    await rc.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: _fetchTimeout,
      // Always fetch fresh values at startup — one call per launch is well
      // within Firebase's rate limits.
      minimumFetchInterval: Duration.zero,
    ));
    await rc.setDefaults(_defaults);

    try {
      await rc.fetchAndActivate();
      debugPrint('[VersionService] Remote Config fetched and activated.');
    } catch (e) {
      debugPrint('[VersionService] Fetch failed — using cached/default values. $e');
    }

    return AppVersionModel.fromRemoteConfig(rc);
  }

  /// Compares the device's installed version against [model.latestVersion].
  ///
  /// - installed < latest  AND  force_update == true  → [UpdateStatus.forceUpdate]
  /// - installed < latest  AND  force_update == false → [UpdateStatus.optionalUpdate]
  /// - installed >= latest                            → [UpdateStatus.upToDate]
  Future<UpdateStatus> determineUpdateStatus(AppVersionModel model) async {
    final packageInfo = await PackageInfo.fromPlatform();
    final installed = packageInfo.version;

    debugPrint('[VersionService] installed=$installed  latest=${model.latestVersion}  force=${model.forceUpdate}');

    if (VersionCompare.isLessThan(installed, model.latestVersion)) {
      return model.forceUpdate
          ? UpdateStatus.forceUpdate
          : UpdateStatus.optionalUpdate;
    }
    return UpdateStatus.upToDate;
  }

  /// Opens the Play Store URL from Remote Config.
  Future<void> openStore(AppVersionModel model) async {
    final url = model.playStoreUrl;
    if (url.isEmpty) {
      debugPrint('[VersionService] play_store_url is empty — skipping launch.');
      return;
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('[VersionService] Cannot launch URL: $url');
    }
  }
}
