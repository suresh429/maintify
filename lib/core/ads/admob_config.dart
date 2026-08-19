import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import '../config/app_config.dart';

/// Single source of truth for all AdMob identifiers.
///
/// Usage:
///   final config = AdMobConfig.current;
///   final bannerId = config.bannerAdUnitId;
///
/// ────────────────────────────────────────────────────────────────────────────
/// BEFORE PUBLISHING TO PRODUCTION
///   1. Create a new AdMob account (or use your existing one).
///   2. Register Android and iOS apps → get real App IDs.
///   3. Create Banner, Interstitial, and Native ad units for each app.
///   4. Replace every placeholder marked [PROD Android] / [PROD iOS] below.
///   5. Update android/app/src/prod/AndroidManifest.xml with the real Android App ID.
///   6. Update ios/Runner/Info.plist (prod variant) with the real iOS App ID.
/// ────────────────────────────────────────────────────────────────────────────
class AdMobConfig {
  /// Whether this config represents the development environment.
  final bool isDev;

  // ── App IDs (declared in native manifests — documented here for reference) ──
  /// Android AdMob App ID. Set in AndroidManifest.xml per flavor.
  final String androidAppId;

  /// iOS AdMob App ID. Set in Info.plist.
  final String iosAppId;

  // ── Banner Ad Unit IDs ──────────────────────────────────────────────────────
  final String androidBannerAdUnitId;
  final String iosBannerAdUnitId;

  // ── Interstitial Ad Unit IDs ────────────────────────────────────────────────
  final String androidInterstitialAdUnitId;
  final String iosInterstitialAdUnitId;

  // ── Native Ad Unit IDs (Phase 3) ────────────────────────────────────────────
  final String androidNativeAdUnitId;
  final String iosNativeAdUnitId;

  const AdMobConfig._({
    required this.isDev,
    required this.androidAppId,
    required this.iosAppId,
    required this.androidBannerAdUnitId,
    required this.iosBannerAdUnitId,
    required this.androidInterstitialAdUnitId,
    required this.iosInterstitialAdUnitId,
    required this.androidNativeAdUnitId,
    required this.iosNativeAdUnitId,
  });

  // ── DEV config — Google's official test IDs ─────────────────────────────────
  // Safe to commit. Google allows these in production builds during testing
  // but they must NEVER appear in a published app (use _prod instead).
  static const AdMobConfig _dev = AdMobConfig._(
    isDev: true,
    // Google test App IDs
    androidAppId: 'ca-app-pub-3940256099942544~3347511713',
    iosAppId: 'ca-app-pub-3940256099942544~1458002511',
    // Google test Banner IDs
    androidBannerAdUnitId: 'ca-app-pub-3940256099942544/6300978111',
    iosBannerAdUnitId: 'ca-app-pub-3940256099942544/2934735716',
    // Google test Interstitial IDs
    androidInterstitialAdUnitId: 'ca-app-pub-3940256099942544/1033173712',
    iosInterstitialAdUnitId: 'ca-app-pub-3940256099942544/4411468910',
    // Google test Native Advanced IDs
    androidNativeAdUnitId: 'ca-app-pub-3940256099942544/2247696110',
    iosNativeAdUnitId: 'ca-app-pub-3940256099942544/3986624511',
  );

  // ── PROD config — replace placeholders before publishing ────────────────────
  static const AdMobConfig _prod = AdMobConfig._(
    isDev: false,
    // [PROD Android] Replace with your production Android AdMob App ID
    androidAppId: 'ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX',
    // [PROD iOS] Replace with your production iOS AdMob App ID
    iosAppId: 'ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX',
    // [PROD Android] Replace with your production Android banner ad unit ID
    androidBannerAdUnitId: 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX',
    // [PROD iOS] Replace with your production iOS banner ad unit ID
    iosBannerAdUnitId: 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX',
    // [PROD Android] Replace with your production Android interstitial ad unit ID
    androidInterstitialAdUnitId: 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX',
    // [PROD iOS] Replace with your production iOS interstitial ad unit ID
    iosInterstitialAdUnitId: 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX',
    // [PROD Android] Replace when Phase 3 launches
    androidNativeAdUnitId: 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX',
    // [PROD iOS] Replace when Phase 3 launches
    iosNativeAdUnitId: 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX',
  );

  /// Returns the correct config for the current build flavor.
  /// DEV flavor → test IDs. PROD flavor → production IDs.
  static AdMobConfig get current =>
      AppConfig.isDevelopment ? _dev : _prod;

  // ── Convenience getters ─────────────────────────────────────────────────────

  /// True when running on a mobile platform (Android or iOS), not web.
  static bool get isMobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Platform-appropriate banner ad unit ID for the current flavor.
  /// Returns empty string on web (ads are disabled on web).
  String get bannerAdUnitId {
    if (!isMobilePlatform) return '';
    return _isAndroid ? androidBannerAdUnitId : iosBannerAdUnitId;
  }

  /// Platform-appropriate interstitial ad unit ID for the current flavor.
  String get interstitialAdUnitId {
    if (!isMobilePlatform) return '';
    return _isAndroid ? androidInterstitialAdUnitId : iosInterstitialAdUnitId;
  }

  /// Platform-appropriate native ad unit ID for the current flavor.
  String get nativeAdUnitId {
    if (!isMobilePlatform) return '';
    return _isAndroid ? androidNativeAdUnitId : iosNativeAdUnitId;
  }
}
