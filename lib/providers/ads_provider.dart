import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../core/ads/ad_config.dart';
import '../core/ads/admob_ids.dart';
import '../core/ads/interstitial_manager.dart';
import '../core/services/firestore_service.dart';

/// Manages advertising configuration streamed from Firestore.
///
/// Single source of truth for ALL ad decisions:
///
///   effectiveBannerEnabled =
///       !kIsWeb
///       AND adConfig.adsEnabled
///       AND adConfig.bannerEnabled
///       AND apartmentAdsEnabled
///
/// Safe defaults: everything OFF until Firestore confirms otherwise.
/// (Firestore unavailable → ads stay disabled; never accidentally shown.)
///
/// Lifecycle:
///   1. Registered in main.dart MultiProvider.
///   2. [startListening(aptId)] called by DashboardRouter._StreamStarter.
///   3. Widgets read [effectiveBannerEnabled] / [adConfig].
///   4. Admin screens call [updateAdConfig] / [setApartmentAdsEnabled].
class AdsProvider extends ChangeNotifier {
  final _fs = FirestoreService();

  // ── State ────────────────────────────────────────────────────────────────────

  AdConfig _adConfig = AdConfig.defaultOff();
  bool _apartmentAdsEnabled = false; // safe default OFF
  bool _configLoaded = false;
  bool _aptLoaded = false;

  StreamSubscription<AdConfig>? _configSub;
  StreamSubscription<bool>? _aptSub;

  // ── Public getters ───────────────────────────────────────────────────────────

  AdConfig get adConfig => _adConfig;

  /// True when BOTH Firestore streams have emitted at least one value.
  bool get isLoaded => _configLoaded && _aptLoaded;

  bool get globalAdsEnabled => _adConfig.adsEnabled;
  bool get apartmentAdsEnabled => _apartmentAdsEnabled;

  /// The single flag used by [AdBanner] for banner ads.
  bool get effectiveBannerEnabled {
    if (kIsWeb || !AdMobIds.isMobilePlatform) return false;
    if (!_configLoaded || !_aptLoaded) return false;
    return _adConfig.adsEnabled &&
        _adConfig.bannerEnabled &&
        _apartmentAdsEnabled;
  }

  /// Convenience alias used by existing widgets.
  bool get effectiveAdsEnabled => effectiveBannerEnabled;

  /// True when interstitials should be considered for eligible transitions.
  bool get effectiveInterstitialEnabled {
    if (kIsWeb || !AdMobIds.isMobilePlatform) return false;
    if (!_configLoaded || !_aptLoaded) return false;
    return _adConfig.adsEnabled &&
        _adConfig.interstitialEnabled &&
        _apartmentAdsEnabled;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────────

  /// Called from DashboardRouter._StreamStarter after login.
  /// [aptId] is null/empty for super admins who have no apartment.
  void startListening(String? aptId) {
    _startConfigListener();
    if (aptId != null && aptId.isNotEmpty) {
      _startApartmentListener(aptId);
    } else {
      // Super admin — no apartment; mark loaded with false (no resident ads).
      _aptLoaded = true;
      _apartmentAdsEnabled = false;
    }
  }

  void _startConfigListener() {
    _configSub?.cancel();
    _configSub = _fs.streamAdConfig().listen(
      (config) {
        _adConfig = config;
        _configLoaded = true;
        notifyListeners();
        // Preload interstitial if newly enabled.
        if (effectiveInterstitialEnabled) {
          InterstitialManager.instance.preload(config);
        }
      },
      onError: (_) {
        // Keep safe default (off) and mark loaded so UI can proceed.
        _configLoaded = true;
        notifyListeners();
      },
    );
  }

  void _startApartmentListener(String aptId) {
    _aptSub?.cancel();
    _aptSub = _fs.streamApartmentAdsConfig(aptId).listen(
      (enabled) {
        _apartmentAdsEnabled = enabled;
        _aptLoaded = true;
        notifyListeners();
      },
      onError: (_) {
        _aptLoaded = true;
        notifyListeners();
      },
    );
  }

  // ── Admin write operations ───────────────────────────────────────────────────

  /// Super admin: update the full global ad configuration.
  Future<void> updateAdConfig(AdConfig config, String updatedBy) {
    return _fs.updateAdConfig(config, updatedBy: updatedBy);
  }

  // Kept for president_advertising_screen.dart compatibility.
  Future<void> setGlobalAdsEnabled(bool enabled, String updatedBy) {
    final updated = _adConfig.copyWith(adsEnabled: enabled);
    return _fs.updateAdConfig(updated, updatedBy: updatedBy);
  }

  Future<void> setApartmentAdsEnabled(
      String aptId, bool enabled, String updatedBy) {
    return _fs.updateApartmentAdsEnabled(
      aptId: aptId,
      adsEnabled: enabled,
      updatedBy: updatedBy,
    );
  }

  @override
  void dispose() {
    _configSub?.cancel();
    _aptSub?.cancel();
    InterstitialManager.instance.dispose();
    super.dispose();
  }
}
