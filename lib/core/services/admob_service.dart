import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../ads/admob_config.dart';
import '../ads/admob_ids.dart';

/// Central AdMob initialisation service.
///
/// • Must be called once during [bootstrap()] after Firebase.initializeApp.
/// • Gracefully no-ops on Web and unsupported platforms.
/// • Ad unit IDs are sourced from [AdMobIds] → [AdMobConfig.current].
///   DEV flavor  → Google official test IDs (hardcoded).
///   PROD flavor → Real IDs supplied via --dart-define at build time.
class AdMobService {
  AdMobService._();

  /// Initialise the Google Mobile Ads SDK.
  /// Safe to call on every platform — exits immediately on web/desktop.
  static Future<void> initialize() async {
    if (!AdMobIds.isMobilePlatform) return;

    // Log configuration status in debug builds only.
    // Production release builds never print ad unit IDs.
    if (kDebugMode) {
      final cfg = AdMobConfig.current; // triggers env + config logging
      debugPrint('[AdMob] Banner configured : ${cfg.isBannerConfigured}');
    }

    try {
      await MobileAds.instance.initialize();
      if (kDebugMode) debugPrint('[AdMob] SDK initialized.');
    } catch (e) {
      // Initialization failure must never crash Maintify.
      if (kDebugMode) debugPrint('[AdMob] Initialization failed: $e');
    }
  }

  // Delegate to AdMobIds for backward compatibility.
  static String get bannerAdUnitId => AdMobIds.bannerAdUnitId;
  static String get interstitialAdUnitId => AdMobIds.interstitialAdUnitId;
}
