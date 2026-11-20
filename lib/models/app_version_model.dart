/// Immutable snapshot of the three version-control values from Firestore.
class AppVersionModel {
  final String latestVersion;
  final bool forceUpdate;
  final String playStoreUrl;

  const AppVersionModel({
    required this.latestVersion,
    required this.forceUpdate,
    required this.playStoreUrl,
  });

  factory AppVersionModel.fromMap(Map<String, dynamic> map) {
    return AppVersionModel(
      latestVersion: (map['latestVersion'] as String? ?? '').trim(),
      forceUpdate:   map['forceUpdate']   as bool?   ?? false,
      playStoreUrl:  (map['playStoreUrl'] as String? ?? '').trim(),
    );
  }

  static const AppVersionModel empty = AppVersionModel(
    latestVersion: '0.0.0',
    forceUpdate:   false,
    playStoreUrl:  '',
  );
}
