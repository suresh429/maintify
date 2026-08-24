import 'package:flutter/foundation.dart'
    show kIsWeb, kDebugMode, debugPrint, defaultTargetPlatform, TargetPlatform;
import '../config/app_config.dart';

/// Single source of truth for all AdMob identifiers.
///
/// ════════════════════════════════════════════════════════════════════════════
/// ENVIRONMENT SELECTION
/// ════════════════════════════════════════════════════════════════════════════
///
/// DEV flavor  → always Google's official test IDs (hardcoded, safe to commit,
///               never overridable by --dart-define in dev builds).
///
/// PROD flavor → IDs are resolved at compile time from --dart-define values.
///               If a --dart-define is not supplied the value falls back to the
///               placeholder string, which will NOT display real ads.
///
/// ════════════════════════════════════════════════════════════════════════════
/// HOW TO CONFIGURE PRODUCTION AD UNIT IDs
/// ════════════════════════════════════════════════════════════════════════════
///
/// Pass each ID as a --dart-define flag when building for production:
///
///   flutter build appbundle --flavor prod -t lib/main_prod.dart \
///     --dart-define=ADMOB_PROD_ANDROID_APP_ID=ca-app-pub-REAL~APPID \
///     --dart-define=ADMOB_PROD_IOS_APP_ID=ca-app-pub-REAL~APPID \
///     --dart-define=ADMOB_PROD_ANDROID_BANNER_ID=ca-app-pub-REAL/BANNERID \
///     --dart-define=ADMOB_PROD_IOS_BANNER_ID=ca-app-pub-REAL/BANNERID \
///     --dart-define=ADMOB_PROD_ANDROID_INTERSTITIAL_ID=ca-app-pub-REAL/INTID \
///     --dart-define=ADMOB_PROD_IOS_INTERSTITIAL_ID=ca-app-pub-REAL/INTID \
///     --dart-define=ADMOB_PROD_ANDROID_NATIVE_ID=ca-app-pub-REAL/NATIVEID \
///     --dart-define=ADMOB_PROD_IOS_NATIVE_ID=ca-app-pub-REAL/NATIVEID
///
///   flutter build ipa --flavor prod -t lib/main_prod.dart \
///     --dart-define=ADMOB_PROD_IOS_APP_ID=ca-app-pub-REAL~APPID \
///     --dart-define=ADMOB_PROD_IOS_BANNER_ID=ca-app-pub-REAL/BANNERID \
///     ... (same pattern)
///
/// Note: App IDs (APP_ID) must also be updated in native manifests:
///   Android : android/app/src/prod/AndroidManifest.xml
///   iOS     : ios/inject_admob_id.sh  (PROD_ADMOB_APP_ID variable)
///
/// ════════════════════════════════════════════════════════════════════════════
/// USAGE
/// ════════════════════════════════════════════════════════════════════════════
///
///   final config = AdMobConfig.current;
///   final bannerId = config.bannerAdUnitId;   // platform-appropriate
///
class AdMobConfig {
  /// Whether this config represents the development environment.
  final bool isDev;

  // ── App IDs (declared in native manifests — documented here for reference) ──
  /// Android AdMob App ID. Set in AndroidManifest.xml per flavor.
  final String androidAppId;

  /// iOS AdMob App ID. Set in Info.plist via ios/inject_admob_id.sh.
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

  // ── Sentinel values — detect unconfigured prod placeholders ─────────────────

  static const String _kUnsetAdUnit = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String _kUnsetAppId  = 'ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX';

  // ── DEV config — Google's official test IDs ─────────────────────────────────
  //
  // These IDs are hardcoded and intentionally cannot be overridden via
  // --dart-define in a dev build.  They are safe to commit: Google publishes
  // them in the official documentation for testing purposes only.
  //
  // Reference: https://developers.google.com/admob/flutter/test-ads
  static const AdMobConfig _dev = AdMobConfig._(
    isDev: true,
    // Google's official test App IDs
    androidAppId: 'ca-app-pub-3940256099942544~3347511713',
    iosAppId:     'ca-app-pub-3940256099942544~1458002511',
    // Google's official test Banner Ad Unit IDs
    androidBannerAdUnitId: 'ca-app-pub-3940256099942544/6300978111',
    iosBannerAdUnitId:     'ca-app-pub-3940256099942544/2934735716',
    // Google's official test Interstitial Ad Unit IDs
    androidInterstitialAdUnitId: 'ca-app-pub-3940256099942544/1033173712',
    iosInterstitialAdUnitId:     'ca-app-pub-3940256099942544/4411468910',
    // Google's official test Native Advanced Ad Unit IDs
    androidNativeAdUnitId: 'ca-app-pub-3940256099942544/2247696110',
    iosNativeAdUnitId:     'ca-app-pub-3940256099942544/3986624511',
  );

  // ── PROD config — resolved from --dart-define at compile time ───────────────
  //
  // Each value is supplied via --dart-define=<KEY>=<value> when building.
  // If a key is absent the placeholder default is used, which will NOT display
  // real ads and will trigger a warning in debug builds.
  //
  // Keys:
  //   ADMOB_PROD_ANDROID_APP_ID        — Android AdMob App ID (also in AndroidManifest)
  //   ADMOB_PROD_IOS_APP_ID            — iOS AdMob App ID (also in inject_admob_id.sh)
  //   ADMOB_PROD_ANDROID_BANNER_ID     — Android Banner Ad Unit ID
  //   ADMOB_PROD_IOS_BANNER_ID         — iOS Banner Ad Unit ID
  //   ADMOB_PROD_ANDROID_INTERSTITIAL_ID
  //   ADMOB_PROD_IOS_INTERSTITIAL_ID
  //   ADMOB_PROD_ANDROID_NATIVE_ID
  //   ADMOB_PROD_IOS_NATIVE_ID
  static const AdMobConfig _prod = AdMobConfig._(
    isDev: false,
    // Android PROD App ID — real production ID (also set in android/app/src/prod/AndroidManifest.xml)
    androidAppId: String.fromEnvironment(
      'ADMOB_PROD_ANDROID_APP_ID',
      defaultValue: 'ca-app-pub-5097788367258292~4281310723',
    ),
    // iOS PROD App ID — not released yet; supply via --dart-define when ready
    iosAppId: String.fromEnvironment(
      'ADMOB_PROD_IOS_APP_ID',
      defaultValue: _kUnsetAppId,
    ),
    // Android PROD Banner Ad Unit ID — real production ID
    androidBannerAdUnitId: String.fromEnvironment(
      'ADMOB_PROD_ANDROID_BANNER_ID',
      defaultValue: 'ca-app-pub-5097788367258292/5961097598',
    ),
    // iOS PROD Banner Ad Unit ID — not released yet; supply via --dart-define when ready
    iosBannerAdUnitId: String.fromEnvironment(
      'ADMOB_PROD_IOS_BANNER_ID',
      defaultValue: _kUnsetAdUnit,
    ),
    // Android PROD Interstitial Ad Unit ID — real production ID
    androidInterstitialAdUnitId: String.fromEnvironment(
      'ADMOB_PROD_ANDROID_INTERSTITIAL_ID',
      defaultValue: 'ca-app-pub-5097788367258292/5825366227',
    ),
    // iOS PROD Interstitial Ad Unit ID — not released yet; supply via --dart-define when ready
    iosInterstitialAdUnitId: String.fromEnvironment(
      'ADMOB_PROD_IOS_INTERSTITIAL_ID',
      defaultValue: _kUnsetAdUnit,
    ),
    // Android PROD Native Ad Unit ID — real production ID
    androidNativeAdUnitId: String.fromEnvironment(
      'ADMOB_PROD_ANDROID_NATIVE_ID',
      defaultValue: 'ca-app-pub-5097788367258292/7956705545',
    ),
    // iOS PROD Native Ad Unit ID — not released yet; supply via --dart-define when ready
    iosNativeAdUnitId: String.fromEnvironment(
      'ADMOB_PROD_IOS_NATIVE_ID',
      defaultValue: _kUnsetAdUnit,
    ),
  );

  // ── Config selector ─────────────────────────────────────────────────────────

  /// Returns the correct config for the current build flavor.
  ///
  /// DEV  → Google test IDs (hardcoded, always safe).
  /// PROD → IDs from --dart-define values compiled in at build time.
  static AdMobConfig get current {
    if (AppConfig.isDevelopment) {
      if (kDebugMode) {
        debugPrint('[AdMob] Environment : DEV');
        debugPrint('[AdMob] Banner ID   : TEST (${_isAndroid ? _dev.androidBannerAdUnitId : _dev.iosBannerAdUnitId})');
      }
      return _dev;
    }

    // PROD — validate that real IDs have been supplied.
    if (kDebugMode) {
      final bannerOk = !_prod.androidBannerAdUnitId.contains('XXXXXXXXXXXXXXXX') &&
                       !_prod.iosBannerAdUnitId.contains('XXXXXXXXXXXXXXXX');
      debugPrint('[AdMob] Environment : PROD');
      debugPrint('[AdMob] Banner ID   : ${bannerOk ? "CONFIGURED" : "NOT CONFIGURED — placeholder in use"}');
      if (!bannerOk) {
        debugPrint('[AdMob] ⚠  Pass --dart-define=ADMOB_PROD_ANDROID_BANNER_ID=<id>');
        debugPrint('[AdMob] ⚠  Pass --dart-define=ADMOB_PROD_IOS_BANNER_ID=<id>');
      }
    }

    return _prod;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// True when running on Android or iOS (not web/desktop).
  static bool get isMobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Platform-appropriate Banner Ad Unit ID for the current flavor.
  /// Returns empty string on web (ads are disabled on web).
  String get bannerAdUnitId {
    if (!isMobilePlatform) return '';
    return _isAndroid ? androidBannerAdUnitId : iosBannerAdUnitId;
  }

  /// Platform-appropriate Interstitial Ad Unit ID for the current flavor.
  String get interstitialAdUnitId {
    if (!isMobilePlatform) return '';
    return _isAndroid ? androidInterstitialAdUnitId : iosInterstitialAdUnitId;
  }

  /// Platform-appropriate Native Ad Unit ID for the current flavor.
  String get nativeAdUnitId {
    if (!isMobilePlatform) return '';
    return _isAndroid ? androidNativeAdUnitId : iosNativeAdUnitId;
  }

  /// True if this config has all prod ad unit IDs configured (non-placeholder).
  /// Always true for DEV (test IDs are always valid).
  bool get isBannerConfigured =>
      isDev || !bannerAdUnitId.contains('XXXXXXXXXXXXXXXX');
}
