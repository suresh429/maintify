import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../core/ads/admob_ids.dart';
import '../providers/ads_provider.dart';
import '../providers/connectivity_provider.dart';

/// Reusable adaptive banner ad widget.
///
/// Returns [SizedBox.shrink()] (zero space) when:
///   • running on Web or unsupported platform
///   • [AdsProvider.effectiveBannerEnabled] is false
///   • AdMob fails to load (after retries are exhausted)
///
/// Ad-load lifecycle
/// ─────────────────
///   1. [didChangeDependencies] fires when [AdsProvider] notifies.
///   2. Load is triggered only when: enabled AND no existing ad AND not
///      currently loading AND no scheduled retry is pending.
///   3. On failure, a bounded retry (10 s → 30 s → 60 s) is scheduled.
///      [_isRetryPending] prevents [didChangeDependencies] from bypassing
///      the backoff when Firestore fires additional notifyListeners() calls.
///   4. [_loadGeneration] invalidates stale Future.delayed callbacks after
///      the ad is intentionally disposed (e.g. ads disabled by admin).
///
/// Always disposes [BannerAd] on removal to prevent memory leaks.
class MaintifyBannerAd extends StatefulWidget {
  const MaintifyBannerAd({super.key});

  @override
  State<MaintifyBannerAd> createState() => _MaintifyBannerAdState();
}

class _MaintifyBannerAdState extends State<MaintifyBannerAd> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  bool _isLoadingAd = false;   // guards against concurrent _loadAd() calls
  bool _isRetryPending = false; // true while a Future.delayed retry is waiting
  int _retryCount = 0;
  static const int _maxRetries = 3;
  // Retry delays: 10 s, 30 s, 60 s
  static const List<int> _retryDelaysSeconds = [10, 30, 60];

  /// Incremented every time the ad is disposed (e.g. ads disabled or widget
  /// removed). Stale Future.delayed retry callbacks compare their captured
  /// generation and bail out if the counter has since advanced.
  int _loadGeneration = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ads = context.watch<AdsProvider>();
    final enabled = ads.effectiveBannerEnabled;
    debugPrint('[MaintifyBannerAd] didChangeDependencies — '
        'effectiveBannerEnabled=$enabled '
        'isLoaded=${ads.isLoaded} globalAds=${ads.globalAdsEnabled} '
        'aptAds=${ads.apartmentAdsEnabled} '
        'retryPending=$_isRetryPending isLoadingAd=$_isLoadingAd');

    if (enabled &&
        _bannerAd == null &&
        !_isAdLoaded &&
        !_isLoadingAd &&
        !_isRetryPending) {
      _loadAd();
    } else if (!enabled && _bannerAd != null) {
      _disposeAd();
    }
  }

  Future<void> _loadAd() async {
    if (kIsWeb || !AdMobIds.isMobilePlatform) {
      debugPrint('[MaintifyBannerAd] skipped — web or unsupported platform');
      return;
    }
    final adUnitId = AdMobIds.bannerAdUnitId;
    if (adUnitId.isEmpty) {
      debugPrint('[MaintifyBannerAd] skipped — adUnitId is empty');
      return;
    }

    // Synchronously guard against concurrent calls before the first await.
    if (_isLoadingAd) return;
    _isLoadingAd = true;

    final width = MediaQuery.of(context).size.width.truncate();
    final adaptiveSize =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);

    if (!mounted) {
      _isLoadingAd = false;
      return;
    }

    // Use adaptive size when available; fall back to fixed 320×50 banner when
    // the adaptive calculation returns null (e.g. degraded WebView on some OEM
    // devices). The fixed size is universally supported and does not require a
    // WebView-based size calculation.
    final AdSize adSize = adaptiveSize ?? AdSize.banner;
    if (adaptiveSize == null) {
      debugPrint('[MaintifyBannerAd] adaptive size returned null '
          '(width=$width) — using AdSize.banner fallback');
    }

    debugPrint('[MaintifyBannerAd] loading ad — '
        'unit=$adUnitId '
        'adSize=${adSize.width}×${adSize.height} '
        'retry=$_retryCount/$_maxRetries');

    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          debugPrint('[MaintifyBannerAd] onAdLoaded — ad is ready to display');
          _isLoadingAd = false;
          _isRetryPending = false;
          _retryCount = 0;
          if (mounted) setState(() => _isAdLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[MaintifyBannerAd] onAdFailedToLoad — '
              'code=${error.code} '
              'domain=${error.domain} '
              'message=${error.message} '
              'retry=$_retryCount/$_maxRetries');
          // Log ResponseInfo when available — surfaces the mediation adapter
          // that failed and helps distinguish SSL/network vs AdMob policy errors.
          final responseInfo = error.responseInfo;
          if (responseInfo != null) {
            debugPrint('[MaintifyBannerAd] ResponseInfo: '
                'responseId=${responseInfo.responseId} '
                'adapter=${responseInfo.mediationAdapterClassName}');
          }
          ad.dispose();
          _bannerAd = null;
          _isLoadingAd = false;
          if (mounted) setState(() => _isAdLoaded = false);
          _scheduleRetry();
        },
      ),
    )..load();
  }

  void _scheduleRetry() {
    if (!mounted) return;
    if (_retryCount >= _maxRetries) {
      debugPrint('[MaintifyBannerAd] max retries reached ($_retryCount/$_maxRetries) — giving up');
      return;
    }
    final delaySeconds = _retryDelaysSeconds[_retryCount];
    _retryCount++;
    // Mark a retry as pending so didChangeDependencies does NOT trigger an
    // immediate additional load while this Future.delayed is waiting.
    _isRetryPending = true;
    // Capture the current generation so this closure can detect if the ad was
    // disposed (counter incremented) before the delay fires.
    final capturedGeneration = _loadGeneration;
    debugPrint('[MaintifyBannerAd] retry $_retryCount scheduled in ${delaySeconds}s '
        '(generation=$capturedGeneration)');
    Future.delayed(Duration(seconds: delaySeconds), () {
      _isRetryPending = false;
      if (!mounted) return;
      if (_loadGeneration != capturedGeneration) {
        debugPrint('[MaintifyBannerAd] retry cancelled — generation mismatch '
            '(expected=$capturedGeneration current=$_loadGeneration)');
        return;
      }
      // Skip retry when the device is confirmed offline — the ad request would
      // fail immediately (SSL/network error) and waste a retry slot.
      final connectivity = context.read<ConnectivityProvider>();
      if (connectivity.isDisconnected) {
        debugPrint('[MaintifyBannerAd] retry skipped — device is offline');
        // Keep _isRetryPending = false so the next notifyListeners() can try.
        return;
      }
      final enabled = context.read<AdsProvider>().effectiveBannerEnabled;
      if (enabled && _bannerAd == null && !_isAdLoaded && !_isLoadingAd) {
        _loadAd();
      }
    });
  }

  void _disposeAd() {
    _loadGeneration++; // invalidate any pending retry Future.delayed callbacks
    _bannerAd?.dispose();
    _bannerAd = null;
    _isLoadingAd = false;
    _isRetryPending = false;
    _retryCount = 0;
    if (mounted) setState(() => _isAdLoaded = false);
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !AdMobIds.isMobilePlatform) return const SizedBox.shrink();

    final enabled = context.watch<AdsProvider>().effectiveBannerEnabled;
    if (!enabled || !_isAdLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      top: false,
      child: Center(
        child: SizedBox(
          width: _bannerAd!.size.width.toDouble(),
          height: _bannerAd!.size.height.toDouble(),
          child: AdWidget(ad: _bannerAd!),
        ),
      ),
    );
  }
}
