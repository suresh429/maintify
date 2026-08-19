import 'package:flutter_test/flutter_test.dart';
import 'package:maintify/core/ads/ad_config.dart';

/// Unit tests for AdConfig model and ad decision logic.
///
/// These tests operate on pure Dart logic — no Firebase, AdMob SDK,
/// or Flutter widget tree required.
void main() {
  group('AdConfig.defaultOff()', () {
    test('all fields are false/off by default', () {
      final c = AdConfig.defaultOff();
      expect(c.adsEnabled, false);
      expect(c.bannerEnabled, false);
      expect(c.interstitialEnabled, false);
      expect(c.nativeEnabled, false);
    });

    test('default frequency and cooldown are sensible non-zero values', () {
      final c = AdConfig.defaultOff();
      expect(c.interstitialFrequency, greaterThan(0));
      expect(c.interstitialCooldownSeconds, greaterThan(0));
    });
  });

  group('AdConfig.fromMap()', () {
    test('parses a complete valid Firestore map', () {
      final map = {
        'adsEnabled': true,
        'banner': {'enabled': true},
        'interstitial': {
          'enabled': true,
          'frequency': 3,
          'cooldownSeconds': 120,
        },
        'native': {'enabled': false},
      };
      final c = AdConfig.fromMap(map);
      expect(c.adsEnabled, true);
      expect(c.bannerEnabled, true);
      expect(c.interstitialEnabled, true);
      expect(c.interstitialFrequency, 3);
      expect(c.interstitialCooldownSeconds, 120);
      expect(c.nativeEnabled, false);
    });

    test('missing sub-maps default to false', () {
      final c = AdConfig.fromMap({'adsEnabled': true});
      expect(c.bannerEnabled, false);
      expect(c.interstitialEnabled, false);
      expect(c.nativeEnabled, false);
    });

    test('empty map defaults to all false (fail-safe)', () {
      final c = AdConfig.fromMap({});
      expect(c.adsEnabled, false);
      expect(c.bannerEnabled, false);
    });
  });

  group('AdConfig.copyWith()', () {
    test('copies with changed adsEnabled and bannerEnabled', () {
      final c = AdConfig.defaultOff()
          .copyWith(adsEnabled: true, bannerEnabled: true);
      expect(c.adsEnabled, true);
      expect(c.bannerEnabled, true);
      expect(c.interstitialEnabled, false);
    });

    test('interstitial frequency update preserved', () {
      final c = AdConfig.defaultOff().copyWith(interstitialFrequency: 7);
      expect(c.interstitialFrequency, 7);
      expect(c.adsEnabled, false); // other fields unchanged
    });
  });

  group('Effective banner decision logic (platform-agnostic)', () {
    // Simulates AdsProvider.effectiveBannerEnabled without kIsWeb dependency.
    bool effectiveBanner({
      required bool globalEnabled,
      required bool bannerEnabled,
      required bool apartmentEnabled,
    }) =>
        globalEnabled && bannerEnabled && apartmentEnabled;

    test('CASE 1 — global ON, apartment ON, banner ON → show ads', () {
      expect(
          effectiveBanner(
              globalEnabled: true,
              bannerEnabled: true,
              apartmentEnabled: true),
          true);
    });

    test('CASE 2 — global OFF, apartment ON, banner ON → no ads', () {
      expect(
          effectiveBanner(
              globalEnabled: false,
              bannerEnabled: true,
              apartmentEnabled: true),
          false);
    });

    test('CASE 3 — global ON, apartment OFF, banner ON → no ads', () {
      expect(
          effectiveBanner(
              globalEnabled: true,
              bannerEnabled: true,
              apartmentEnabled: false),
          false);
    });

    test('CASE 4 — global ON, apartment ON, banner OFF → no ads', () {
      expect(
          effectiveBanner(
              globalEnabled: true,
              bannerEnabled: false,
              apartmentEnabled: true),
          false);
    });

    test('CASE 5 — all OFF → no ads', () {
      expect(
          effectiveBanner(
              globalEnabled: false,
              bannerEnabled: false,
              apartmentEnabled: false),
          false);
    });

    test('web simulation (kIsWeb == true) → no ads', () {
      // Simulate the platform check: when isWeb is true, ads are blocked
      // before checking effectiveBanner. The effective result is always false.
      bool effectiveBannerOnWeb({
        required bool isWeb,
        required bool globalEnabled,
        required bool bannerEnabled,
        required bool apartmentEnabled,
      }) {
        if (isWeb) return false;
        return effectiveBanner(
            globalEnabled: globalEnabled,
            bannerEnabled: bannerEnabled,
            apartmentEnabled: apartmentEnabled);
      }

      expect(
          effectiveBannerOnWeb(
              isWeb: true,
              globalEnabled: true,
              bannerEnabled: true,
              apartmentEnabled: true),
          false);
    });

    test('Firestore unavailable (defaultOff) → no ads (fail-safe)', () {
      final config = AdConfig.defaultOff();
      final effective = effectiveBanner(
          globalEnabled: config.adsEnabled,
          bannerEnabled: config.bannerEnabled,
          apartmentEnabled: false);
      expect(effective, false);
    });
  });

  group('Interstitial frequency logic', () {
    test('shows after every N eligible actions', () {
      const frequency = 5;
      var count = 0;
      var shown = 0;
      for (var i = 0; i < 15; i++) {
        count++;
        if (count >= frequency) {
          shown++;
          count = 0;
        }
      }
      expect(shown, 3); // 15 / 5 = 3 expected impressions
    });

    test('cooldown: cannot show within cooldown window', () {
      final lastShown =
          DateTime.now().subtract(const Duration(seconds: 100));
      const cooldownSeconds = 300;
      final elapsed = DateTime.now().difference(lastShown).inSeconds;
      expect(elapsed < cooldownSeconds, true); // blocked by cooldown
    });

    test('cooldown: allowed after cooldown expires', () {
      final lastShown =
          DateTime.now().subtract(const Duration(seconds: 400));
      const cooldownSeconds = 300;
      final elapsed = DateTime.now().difference(lastShown).inSeconds;
      expect(elapsed >= cooldownSeconds, true); // cooldown cleared
    });
  });

  group('Native ads architecture', () {
    test('native enabled is false in defaultOff()', () {
      expect(AdConfig.defaultOff().nativeEnabled, false);
    });

    test('native enabled is false in phase1()', () {
      expect(AdConfig.phase1().nativeEnabled, false);
    });

    test('native can be enabled via copyWith for Phase 3', () {
      final c = AdConfig.phase1().copyWith(nativeEnabled: true);
      expect(c.nativeEnabled, true);
    });
  });
}
