import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../core/ads/admob_ids.dart';
import '../providers/ads_provider.dart';

/// Reusable adaptive banner ad widget.
///
/// Returns [SizedBox.shrink()] (zero space) when:
///   • running on Web or unsupported platform
///   • [AdsProvider.effectiveBannerEnabled] is false
///   • AdMob fails to load
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
  bool _isLoadingAd = false; // guards against concurrent _loadAd() calls
  int _retryCount = 0;
  static const int _maxRetries = 3;
  // Retry delays: 10s, 30s, 60s
  static const List<int> _retryDelaysSeconds = [10, 30, 60];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ads = context.watch<AdsProvider>();
    final enabled = ads.effectiveBannerEnabled;
    debugPrint('[MaintifyBannerAd] didChangeDependencies — effectiveBannerEnabled=$enabled '
        'configLoaded=${ads.isLoaded} globalAds=${ads.globalAdsEnabled} '
        'aptAds=${ads.apartmentAdsEnabled}');
    if (enabled && _bannerAd == null && !_isAdLoaded && !_isLoadingAd) {
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

    // Synchronously guard against concurrent calls before the first await
    if (_isLoadingAd) return;
    _isLoadingAd = true;

    final width = MediaQuery.of(context).size.width.truncate();
    final adSize =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    if (!mounted || adSize == null) {
      _isLoadingAd = false;
      return;
    }

    debugPrint('[MaintifyBannerAd] loading adaptive ad — unit=$adUnitId width=$width retry=$_retryCount');

    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          debugPrint('[MaintifyBannerAd] ad loaded successfully');
          _isLoadingAd = false;
          _retryCount = 0;
          if (mounted) setState(() => _isAdLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[MaintifyBannerAd] ad FAILED to load: code=${error.code} '
              'message=${error.message} domain=${error.domain} '
              'retry=$_retryCount/$_maxRetries');
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
      debugPrint('[MaintifyBannerAd] max retries reached — giving up');
      return;
    }
    final delaySeconds = _retryDelaysSeconds[_retryCount];
    _retryCount++;
    debugPrint('[MaintifyBannerAd] scheduling retry $_retryCount in ${delaySeconds}s');
    Future.delayed(Duration(seconds: delaySeconds), () {
      if (!mounted) return;
      final enabled = context.read<AdsProvider>().effectiveBannerEnabled;
      if (enabled && _bannerAd == null && !_isAdLoaded && !_isLoadingAd) {
        _loadAd();
      }
    });
  }

  void _disposeAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isLoadingAd = false;
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
