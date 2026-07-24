import 'package:firebase_remote_config/firebase_remote_config.dart';

/// Immutable snapshot of the three version-control values from Firebase
/// Remote Config. Nothing is hardcoded — all values are Remote Config driven.
class AppVersionModel {
  final String latestVersion;
  final bool forceUpdate;
  final String playStoreUrl;

  const AppVersionModel({
    required this.latestVersion,
    required this.forceUpdate,
    required this.playStoreUrl,
  });

  factory AppVersionModel.fromRemoteConfig(FirebaseRemoteConfig config) {
    return AppVersionModel(
      latestVersion: config.getString('latest_version').trim(),
      forceUpdate: config.getBool('force_update'),
      playStoreUrl: config.getString('play_store_url').trim(),
    );
  }
}
