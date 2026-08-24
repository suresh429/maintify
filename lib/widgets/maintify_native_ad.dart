import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../core/ads/admob_ids.dart';
import '../providers/ads_provider.dart';

/// Reusable medium native ad widget (Phase 3).
///
/// Returns [SizedBox.shrink()] (zero space) when:
///   • running on Web or unsupported platform
///   • [AdsProvider.effectiveNativeEnabled] is false
///   • AdMob fails to load
///
/// Uses Google's built-in medium template — no custom Android XML or iOS XIB
/// layout files required.
class MaintifyNativeAd extends StatefulWidget {
  const MaintifyNativeAd({super.key});

  @override
  State<MaintifyNativeAd> createState() => _MaintifyNativeAdState();
}

class _MaintifyNativeAdState extends State<MaintifyNativeAd> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ads = context.watch<AdsProvider>();
    final enabled = ads.effectiveNativeEnabled;
    debugPrint('[MaintifyNativeAd] didChangeDependencies — effectiveNativeEnabled=$enabled');
    if (enabled && _nativeAd == null) {
      _loadAd();
    } else if (!enabled && _nativeAd != null) {
      _disposeAd();
    }
  }

  void _loadAd() {
    if (kIsWeb || !AdMobIds.isMobilePlatform) return;
    final adUnitId = AdMobIds.nativeAdUnitId;
    if (adUnitId.isEmpty) return;
    debugPrint('[MaintifyNativeAd] loading — unit=$adUnitId');

    _nativeAd = NativeAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
      ),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          debugPrint('[MaintifyNativeAd] loaded successfully');
          if (mounted) setState(() => _isAdLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[MaintifyNativeAd] failed: code=${error.code} message=${error.message}');
          ad.dispose();
          _nativeAd = null;
          if (mounted) setState(() => _isAdLoaded = false);
        },
      ),
    )..load();
  }

  void _disposeAd() {
    _nativeAd?.dispose();
    _nativeAd = null;
    if (mounted) setState(() => _isAdLoaded = false);
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !AdMobIds.isMobilePlatform) return const SizedBox.shrink();
    final enabled = context.watch<AdsProvider>().effectiveNativeEnabled;
    if (!enabled || !_isAdLoaded || _nativeAd == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SizedBox(
        height: 120,
        child: AdWidget(ad: _nativeAd!),
      ),
    );
  }
}
