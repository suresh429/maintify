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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ads = context.watch<AdsProvider>();
    final enabled = ads.effectiveBannerEnabled;
    debugPrint('[MaintifyBannerAd] didChangeDependencies — effectiveBannerEnabled=$enabled '
        'configLoaded=${ads.isLoaded} globalAds=${ads.globalAdsEnabled} '
        'aptAds=${ads.apartmentAdsEnabled}');
    if (enabled && _bannerAd == null) {
      _loadAd();
    } else if (!enabled && _bannerAd != null) {
      _disposeAd();
    }
  }

  void _loadAd() {
    if (kIsWeb || !AdMobIds.isMobilePlatform) {
      debugPrint('[MaintifyBannerAd] skipped — web or unsupported platform');
      return;
    }
    final adUnitId = AdMobIds.bannerAdUnitId;
    if (adUnitId.isEmpty) {
      debugPrint('[MaintifyBannerAd] skipped — adUnitId is empty');
      return;
    }
    debugPrint('[MaintifyBannerAd] loading ad — unit=$adUnitId');

    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          debugPrint('[MaintifyBannerAd] ad loaded successfully');
          if (mounted) setState(() => _isAdLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[MaintifyBannerAd] ad FAILED to load: code=${error.code} message=${error.message} domain=${error.domain}');
          ad.dispose();
          _bannerAd = null;
          if (mounted) setState(() => _isAdLoaded = false);
        },
      ),
    )..load();
  }

  void _disposeAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
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
