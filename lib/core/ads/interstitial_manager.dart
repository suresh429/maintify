import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'admob_ids.dart';
import 'ad_config.dart';

/// Manages interstitial ad loading, frequency, and cooldown.
///
/// Frequency and cooldown are read from [AdConfig] (Firestore) so the admin
/// can tune them without releasing a new app version.
///
/// Rules:
///   1. Global kill switch: [AdConfig.adsEnabled] must be true.
///   2. Interstitial switch: [AdConfig.interstitialEnabled] must be true.
///   3. Apartment switch: apartment ads must be enabled.
///   4. Frequency: show after every [AdConfig.interstitialFrequency] eligible
///      actions (tracked in-memory, resets per session).
///   5. Cooldown: do not show within [AdConfig.interstitialCooldownSeconds]
///      of the last impression.
///
/// Usage:
///   final mgr = InterstitialManager.instance;
///   mgr.recordEligibleAction(config, apartmentAdsEnabled);
class InterstitialManager {
  InterstitialManager._();
  static final InterstitialManager instance = InterstitialManager._();

  InterstitialAd? _ad;
  bool _isLoading = false;
  int _actionCount = 0;
  DateTime? _lastShown;

  // ── Preload ─────────────────────────────────────────────────────────────────

  /// Preload an interstitial so it is ready when needed.
  /// Call this once after login (from DashboardRouter) if interstitials are on.
  void preload(AdConfig config) {
    if (!AdMobIds.isMobilePlatform) return;
    if (!config.adsEnabled || !config.interstitialEnabled) return;
    if (_ad != null || _isLoading) return;

    _isLoading = true;
    InterstitialAd.load(
      adUnitId: AdMobIds.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _isLoading = false;
          _ad!.setImmersiveMode(true);
          if (kDebugMode) debugPrint('[AdMob] Interstitial loaded.');
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          if (kDebugMode) {
            debugPrint('[AdMob] Interstitial load failed: $error');
          }
        },
      ),
    );
  }

  // ── Record eligible action ───────────────────────────────────────────────────

  /// Call this at eligible navigation transitions.
  /// Internally decides whether to show an interstitial.
  ///
  /// [onDismissed] is called after the ad is dismissed OR if no ad is shown.
  void recordEligibleAction({
    required AdConfig config,
    required bool apartmentAdsEnabled,
    void Function()? onDismissed,
  }) {
    if (!_canShow(config, apartmentAdsEnabled)) {
      onDismissed?.call();
      return;
    }

    _actionCount++;

    if (_actionCount >= config.interstitialFrequency) {
      _attemptShow(config, apartmentAdsEnabled, onDismissed);
    } else {
      onDismissed?.call();
    }
  }

  // ── Dispose ──────────────────────────────────────────────────────────────────

  void dispose() {
    _ad?.dispose();
    _ad = null;
    _isLoading = false;
    _actionCount = 0;
    _lastShown = null;
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  bool _canShow(AdConfig config, bool apartmentAdsEnabled) {
    if (!AdMobIds.isMobilePlatform) return false;
    if (!config.adsEnabled) return false;
    if (!config.interstitialEnabled) return false;
    if (!apartmentAdsEnabled) return false;

    // Cooldown check
    if (_lastShown != null) {
      final elapsed = DateTime.now().difference(_lastShown!).inSeconds;
      if (elapsed < config.interstitialCooldownSeconds) return false;
    }

    return true;
  }

  void _attemptShow(
    AdConfig config,
    bool apartmentAdsEnabled,
    void Function()? onDismissed,
  ) {
    final ad = _ad;
    if (ad == null) {
      // Ad not ready — don't block navigation, preload for next time.
      onDismissed?.call();
      preload(config);
      return;
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _ad = null;
        _actionCount = 0;
        _lastShown = DateTime.now();
        onDismissed?.call();
        // Preload the next one.
        preload(config);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _ad = null;
        if (kDebugMode) {
          debugPrint('[AdMob] Interstitial show failed: $error');
        }
        onDismissed?.call();
        preload(config);
      },
    );

    ad.show();
  }
}
