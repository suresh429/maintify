import 'admob_config.dart';

/// Thin facade over [AdMobConfig] — preserves the existing call-sites
/// (`AdMobIds.bannerAdUnitId`, `AdMobIds.isMobilePlatform`, etc.) so no other
/// file needs changing after the AdMobConfig refactor.
class AdMobIds {
  AdMobIds._();

  /// True when running on Android or iOS (not web).
  static bool get isMobilePlatform => AdMobConfig.isMobilePlatform;

  /// Banner ad unit ID for the current platform + flavor.
  static String get bannerAdUnitId => AdMobConfig.current.bannerAdUnitId;

  /// Interstitial ad unit ID for the current platform + flavor.
  static String get interstitialAdUnitId =>
      AdMobConfig.current.interstitialAdUnitId;

  /// Native ad unit ID for the current platform + flavor (Phase 3).
  static String get nativeAdUnitId => AdMobConfig.current.nativeAdUnitId;
}
