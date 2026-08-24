import 'package:cloud_firestore/cloud_firestore.dart';

/// Parsed representation of the `systemConfig/adManagement` Firestore document.
///
/// Safe default for ALL fields is OFF (false/0) so a missing or unreadable
/// document never accidentally enables ads.
class AdConfig {
  final bool adsEnabled;
  final bool bannerEnabled;
  final bool interstitialEnabled;
  final int interstitialFrequency;     // show after every N eligible actions
  final int interstitialCooldownSeconds;
  final bool nativeEnabled;            // Phase 3 — always false until explicitly on
  final DateTime? updatedAt;
  final String? updatedBy;

  const AdConfig({
    required this.adsEnabled,
    required this.bannerEnabled,
    required this.interstitialEnabled,
    required this.interstitialFrequency,
    required this.interstitialCooldownSeconds,
    required this.nativeEnabled,
    this.updatedAt,
    this.updatedBy,
  });

  /// Safe default — everything OFF.
  /// Used when Firestore is unavailable or the document does not exist.
  factory AdConfig.defaultOff() => const AdConfig(
        adsEnabled: false,
        bannerEnabled: false,
        interstitialEnabled: false,
        interstitialFrequency: 5,
        interstitialCooldownSeconds: 300,
        nativeEnabled: false,
      );

  /// Production-ready Phase 1 defaults — banners ON, everything else OFF.
  /// Used only to seed the Firestore document via the Admin UI.
  factory AdConfig.phase1() => const AdConfig(
        adsEnabled: true,
        bannerEnabled: true,
        interstitialEnabled: false,
        interstitialFrequency: 5,
        interstitialCooldownSeconds: 300,
        nativeEnabled: false,
      );

  factory AdConfig.fromMap(Map<String, dynamic> data) {
    final banner = data['banner'] as Map<String, dynamic>? ?? {};
    final interstitial = data['interstitial'] as Map<String, dynamic>? ?? {};
    final native = data['native'] as Map<String, dynamic>? ?? {};

    return AdConfig(
      adsEnabled: (data['adsEnabled'] as bool?) ?? false,
      bannerEnabled: (banner['enabled'] as bool?) ?? false,
      interstitialEnabled: (interstitial['enabled'] as bool?) ?? false,
      interstitialFrequency: (interstitial['frequency'] as int?) ?? 5,
      interstitialCooldownSeconds:
          (interstitial['cooldownSeconds'] as int?) ?? 300,
      nativeEnabled: (native['enabled'] as bool?) ?? false,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      updatedBy: data['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap({required String updatedBy}) => {
        'adsEnabled': adsEnabled,
        'banner': {'enabled': bannerEnabled},
        'interstitial': {
          'enabled': interstitialEnabled,
          'frequency': interstitialFrequency,
          'cooldownSeconds': interstitialCooldownSeconds,
        },
        'native': {'enabled': nativeEnabled},
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
      };

  AdConfig copyWith({
    bool? adsEnabled,
    bool? bannerEnabled,
    bool? interstitialEnabled,
    int? interstitialFrequency,
    int? interstitialCooldownSeconds,
    bool? nativeEnabled,
  }) =>
      AdConfig(
        adsEnabled: adsEnabled ?? this.adsEnabled,
        bannerEnabled: bannerEnabled ?? this.bannerEnabled,
        interstitialEnabled: interstitialEnabled ?? this.interstitialEnabled,
        interstitialFrequency:
            interstitialFrequency ?? this.interstitialFrequency,
        interstitialCooldownSeconds:
            interstitialCooldownSeconds ?? this.interstitialCooldownSeconds,
        nativeEnabled: nativeEnabled ?? this.nativeEnabled,
        updatedAt: updatedAt,
        updatedBy: updatedBy,
      );
}
