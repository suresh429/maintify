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
      debugPrint('[AdMob] App ID     : ${cfg.appId}');
      debugPrint('[AdMob] Banner configured : ${cfg.isBannerConfigured}');
    }

    try {
      // In debug builds, register physical test devices so AdMob serves
      // Google's official test ads instead of real advertiser ads.
      // This block is compiled out of release builds — release APKs/AABs
      // always receive real ads regardless of which device is used.
      if (kDebugMode) {
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(
            testDeviceIds: [
              '6CEFC29E7EDD9047530DEDC819973493', // Realme RMX3933 (dev device)
            ],
          ),
        );
        debugPrint('[AdMob] Test device IDs registered (debug only).');
      }

      final initResult = await MobileAds.instance.initialize();
      if (kDebugMode) {
        debugPrint('[AdMob] SDK initialized.');
        // Log each adapter status to help diagnose partial initialisation
        // issues (e.g. JavascriptEngine not ready on Realme/OPPO devices).
        for (final entry in initResult.adapterStatuses.entries) {
          final status = entry.value;
          debugPrint('[AdMob] Adapter ${entry.key}: '
              'state=${status.state.name} desc=${status.description}');
        }
      }
      // Delay to give the system WebView time to initialise its JavaScript
      // engine on affected OEM devices (Realme, OPPO, Vivo).
      // Without this pause the first ad request may fail with:
      //   "Unable to obtain a JavascriptEngine" (error code 0).
      // 2 s covers devices where WebView falls back to JIT compilation
      // (odex non-executable) which is significantly slower than AOT.
      await Future<void>.delayed(const Duration(milliseconds: 2000));
      if (kDebugMode) debugPrint('[AdMob] Post-init delay complete — WebView engine ready.');
    } catch (e) {
      // Initialization failure must never crash Maintify.
      if (kDebugMode) debugPrint('[AdMob] Initialization failed: $e');
    }
  }

  // Delegate to AdMobIds for backward compatibility.
  static String get bannerAdUnitId => AdMobIds.bannerAdUnitId;
  static String get interstitialAdUnitId => AdMobIds.interstitialAdUnitId;
}
