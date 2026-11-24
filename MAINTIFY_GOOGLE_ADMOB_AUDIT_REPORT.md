# MAINTIFY GOOGLE ADMOB AUDIT REPORT

**Audit Date:** 2026-11-24  
**Application:** Maintify — Flutter Apartment Maintenance Management  
**Package:** `com.maintify.app`  
**Publisher:** `pub-5097788367258292`  
**Auditor:** Claude Code (AI-assisted technical audit)  
**Report Status:** Phase 2 — Findings and Recommendations (read-only inspection)

---

## TABLE OF CONTENTS

- [A. Executive Summary](#a-executive-summary)
- [B. Ad Unit Audit](#b-ad-unit-audit)
- [C. Screen-by-Screen Audit](#c-screen-by-screen-audit)
- [D. Technical Findings](#d-technical-findings)
- [E. Policy and Compliance Audit](#e-policy-and-compliance-audit)
- [F. Revenue Analysis](#f-revenue-analysis)
- [G. Revenue Optimization Strategy](#g-revenue-optimization-strategy)
- [H. Prioritized Action Plan](#h-prioritized-action-plan)
- [I. Expected Impact](#i-expected-impact)
- [J. Testing Report](#j-testing-report)

---

## A. EXECUTIVE SUMMARY

### Overall AdMob Integration Health: FUNCTIONAL BUT UNDER-OPTIMIZED

The Maintify AdMob integration is **architecturally sound** and correctly separated between development and production environments. The three-tier permission model (global kill switch → per-format toggle → per-apartment flag), Firestore-driven configuration, and provider-based state management are well-designed. The integration will not crash, will not accidentally serve ads on web, and will not confuse development and production identifiers on Android.

However, four problems — one technical, one compliance, one volume, and one placement — combine to explain why revenue is low.

### Current Revenue Performance

| Metric | Observed (7-day baseline) |
|---|---|
| Total estimated earnings | $0.05 |
| Total requests | 425 |
| Total impressions | 360 |
| Banner eCPM | $0.05 |
| Interstitial eCPM | $2.65 (10 impressions — unreliable sample) |
| Average daily impressions | ~51 |

$0.05 per week equals approximately **$0.22 per month**. This is not a configuration failure — it is a volume and eCPM problem.

### Four Root Causes of Low Revenue

**1. Fixed legacy banner size instead of adaptive banner.**  
`MaintifyBannerAd` uses `AdSize.banner` (fixed 320×50 pixels). Google's current recommendation is `AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize` or `AdSize.getInlineAdaptiveBannerAdSize`, which fills the available screen width. Adaptive banners consistently deliver higher fill rates and higher eCPM than fixed 320×50 banners. This is documented as the most impactful technical change available.

**2. No Google User Messaging Platform (UMP) consent implementation.**  
There is no `UserMessagingPlatform`, `ConsentInformation`, or `ConsentForm` anywhere in the codebase. Without a consent flow, Google serves **non-personalized ads** by default in regions where consent is required (EEA, UK, Switzerland). Non-personalized ads have significantly lower eCPM (commonly 30–50% lower) than personalized ads. This is also a compliance gap under GDPR. Even for an India-primary audience, missing UMP is a policy risk as Google's global enforcement has expanded.

**3. Very low impression volume indicates limited daily active users.**  
360 impressions over 7 days equals approximately 51 banner impressions per day. Even at a healthy $0.50 eCPM, that volume produces only $9.33 per month. Revenue optimization in Maintify is primarily limited by user volume, not ad configuration. No technical fix will produce meaningful revenue growth without an increase in DAU.

**4. Interstitial triggers are too sparse.**  
Interstitials are triggered only at bottom-navigation tab switches in `ResidentDashboard` and `PresidentDashboard`. This generated only 27 requests in 7 days — fewer than 4 per day. The low show rate (37%) suggests loaded ads are expiring before the frequency threshold is reached: a user must switch tabs `interstitialFrequency` times in one session before an interstitial fires. If users open the app, check one screen, and close it, no interstitial ever fires even though one was preloaded.

### Highest-Priority Opportunities

| Priority | Action | Effort | Revenue Impact |
|---|---|---|---|
| 1 | Upgrade `AdSize.banner` → adaptive banner | Low | High |
| 2 | Implement Google UMP consent flow | Medium | High (compliance + eCPM) |
| 3 | Add banners to 4 additional resident screens | Low | Medium |
| 4 | Add banners to 3 additional president screens | Low | Medium |
| 5 | Expand interstitial trigger points | Low | Low–Medium |
| 6 | Configure iOS production App ID in `inject_admob_id.sh` | Very Low | Unlocks iOS revenue |

---

## B. AD UNIT AUDIT

### B.1 Banner — `Maintify_Android_Banner_Prod`

| Attribute | Value |
|---|---|
| Production Ad Unit ID (Android) | `ca-app-pub-5097788367258292/5961097598` |
| Development Ad Unit ID (Android) | `ca-app-pub-3940256099942544/6300978111` |
| Production iOS Ad Unit ID | Unconfigured — `--dart-define` placeholder |
| Ad size | `AdSize.banner` (fixed 320×50) — **NOT adaptive** |
| Widget | `MaintifyBannerAd` (StatefulWidget) |
| File | `lib/widgets/maintify_banner_ad.dart` |
| Loading strategy | On-demand via `didChangeDependencies()` |
| Disposal | Correct — disposed in `dispose()` and when disabled |
| Error handling | Yes — `onAdFailedToLoad` disposes ad, hides widget |
| Platform guard | Yes — web/non-mobile returns `SizedBox.shrink()` |
| Refresh behaviour | No auto-refresh — Google SDK handles refresh internally |
| Ad request | `AdRequest()` with no extras (no UMP consent extras) |
| Viewability | Wrapped in `SafeArea(top: false)` + `Center` — visible |
| Configuration | Live — `bannerEnabled` controlled via Firestore |
| Policy status | Functional but missing consent signal |
| **Critical issue** | Uses `AdSize.banner` (legacy fixed size) instead of adaptive banner |

**Screens with active banner ads:**
- `lib/screens/resident/bills_screen.dart` — top of screen, above filter tabs
- `lib/screens/shared/community_screen.dart` — top of screen, above TabBar
- `lib/screens/president/president_dashboard.dart` — top of home tab
- `lib/screens/admin/admin_dashboard.dart` — top of mobile home tab

**Recommendation:** Replace `AdSize.banner` with `AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize` using `MediaQuery.of(context).size.width`. See finding TF-01.

---

### B.2 Interstitial — `Maintify_Android_Interstitial_Prod`

| Attribute | Value |
|---|---|
| Production Ad Unit ID (Android) | `ca-app-pub-5097788367258292/5825366227` |
| Development Ad Unit ID (Android) | `ca-app-pub-3940256099942544/1033173712` |
| Production iOS Ad Unit ID | Unconfigured — `--dart-define` placeholder |
| Manager | `InterstitialManager` singleton |
| File | `lib/core/ads/interstitial_manager.dart` |
| Preloading | Yes — triggered reactively when `interstitialEnabled` becomes true in Firestore |
| Frequency control | Yes — `AdConfig.interstitialFrequency` (configurable, Firestore) |
| Cooldown control | Yes — `AdConfig.interstitialCooldownSeconds` (configurable, Firestore) |
| Action counter | In-memory per session — resets after dismissal and on `dispose()` |
| Disposal | Correct — `dispose()` called from `AdsProvider.dispose()` |
| Reload on dismissal | Yes — preloads next interstitial immediately after dismissal |
| Reload on failure | Yes — preloads on `onAdFailedToShowFullScreenContent` |
| Immersive mode | Yes — `setImmersiveMode(true)` applied before show |
| Trigger points | Tab switches in `ResidentDashboard` and `PresidentDashboard` only |
| Configuration | Live — controlled via Firestore `AdConfig` |
| Policy status | Functional — trigger points are natural navigation transitions |
| **Issue** | Very few trigger points → only 27 requests in 7 days |
| **Issue** | Loaded ads expire if frequency threshold not reached in-session |

**Show rate analysis (37%):**  
Of 27 loaded interstitials, only 10 were shown. The likely cause: an interstitial is preloaded, but if the user does not switch tabs `interstitialFrequency` times before closing the app, the loaded ad is never displayed. AdMob interstitials have an internal TTL (typically ~1 hour). The app does not detect ad expiry between sessions. This is not a bug — it is a frequency design tradeoff.

**Recommendation:** Expand trigger points to include navigation to key detail screens (bill detail, complaint detail, notifications). See finding TF-04.

---

### B.3 Native — `Maintify_Android_Native_Prod`

| Attribute | Value |
|---|---|
| Production Ad Unit ID (Android) | `ca-app-pub-5097788367258292/7956705545` |
| Development Ad Unit ID (Android) | `ca-app-pub-3940256099942544/2247696110` |
| Widget | `MaintifyNativeAd` (StatefulWidget) |
| File | `lib/widgets/maintify_native_ad.dart` |
| Template | `TemplateType.small` — Google's built-in native template |
| Height | Fixed 120px |
| Current status | **Disabled by admin configuration** |
| Guard | `effectiveNativeEnabled` returns false when admin sets `nativeEnabled = false` |
| Ad request on disable | No — widget returns `SizedBox.shrink()` immediately |
| Background loading | No — `_loadAd()` is only called when `effectiveNativeEnabled` is true |
| Configuration | Correctly disabled via `AdConfig.nativeEnabled` |
| Policy status | Correctly dormant |

The native ad unit is not broken. It is intentionally disabled. No native ad requests are generated while it is disabled. The architecture is correct for future activation without code changes.

**Recommendation:** Do not enable native ads at this time. When enabled, the current placement (bottom of `ResidentDashboard` home content) is appropriate.

---

### B.4 Rewarded and App Open Ads

No `RewardedAd`, `RewardedInterstitialAd`, or `AppOpenAd` are implemented anywhere in the codebase. This is appropriate:

- **Rewarded ads** require an incentive mechanism (coins, unlockable content). Maintify is a utility app with no virtual currency or gated content. Policy-compliant rewarded ad implementation would require a significant feature addition. Not recommended at this stage.
- **App Open ads** display during cold start. They improve revenue for high-DAU apps but create a poor UX for low-frequency utility apps. Not recommended until DAU grows substantially.

---

## C. SCREEN-BY-SCREEN AUDIT

### Legend
- **Banner:** Has `MaintifyBannerAd` widget
- **Interstitial:** Triggers `InterstitialManager.recordEligibleAction()`
- **Native:** Has `MaintifyNativeAd` widget
- **Financial:** Screen involves financial transactions or entry
- **Critical:** Ads should not appear (auth, payment processing)
- **Opportunity:** Screen is suitable for ad placement but has none

| Screen | File | Current Ads | Financial / Critical | Recommendation |
|---|---|---|---|---|
| **RESIDENT** | | | | |
| Resident Dashboard (home tab) | `resident/resident_dashboard.dart` | Native + Interstitial (tab) | No | Native ad correctly placed at bottom of content. Add interstitial to detail-screen navigation. |
| Bills Screen | `resident/bills_screen.dart` | Banner (top) | Display only | Current placement acceptable. Consider moving banner below filter tabs to avoid accidental interaction at top. |
| Monthly Bill Detail | `resident/monthly_bill_detail_screen.dart` | None | View only | Add banner at bottom below payment options. Do not place near payment buttons. |
| I-Paid Screen | `resident/i_paid_screen.dart` | None | **Financial — entry** | Do not add ads. User is entering transaction reference. Any ad risks accidental clicks during payment. |
| Payment History | `resident/payment_history_screen.dart` | None | View only | Add banner at bottom. This is a view screen, not a transaction screen. |
| Resident Profile | `resident/resident_profile_screen.dart` | None | No | Add banner at bottom of profile. High frequency screen. |
| Complaints | `resident/complaints_screen.dart` | None | No | No ads — this screen is used to file urgent maintenance complaints. Ads would harm trust. |
| Directory | `resident/directory_screen.dart` | None | No | Low priority — add banner at bottom if other placements are live. |
| **PRESIDENT** | | | | |
| President Dashboard (home tab) | `president/president_dashboard.dart` | Banner (top) + Interstitial (tab) | No | Current placement acceptable. |
| Community Fund Overview | `president/community_fund_screen.dart` | None | View only | Add banner at bottom. Summary view, not transaction entry. |
| Fund Transactions | `president/fund_transactions_screen.dart` | None | View only | Add banner at bottom. Transaction history view only. |
| Manage Users | `president/manage_users_screen.dart` | None | No | Add banner at bottom. |
| President Profile | `president/president_profile_screen.dart` | None | No | Add banner at bottom. |
| Monthly Bill Detail (president) | `president/monthly_bill_detail_screen.dart` | None | View only | Low priority — president already sees banner on dashboard. Skip. |
| Create Bill | `president/create_bill_screen.dart` | None | **Financial — entry** | Do not add ads. User is creating billing records. |
| Edit Bill Sheet | `president/edit_bill_sheet.dart` | None | **Financial — entry** | Do not add ads. Bottom sheet form for bill editing. |
| Mark Paid | `president/mark_paid_screen.dart` | None | **Financial — approval** | Do not add ads. User is verifying payment transactions. |
| Add Fund Collection | `president/add_fund_collection_screen.dart` | None | **Financial — entry** | Do not add ads. |
| Add Fund Expense | `president/add_fund_expense_screen.dart` | None | **Financial — entry** | Do not add ads. |
| Transfer President | `president/transfer_president_screen.dart` | None | No | Low importance — skip. |
| UPI Settings | `president/upi_settings_screen.dart` | None | **Sensitive config** | Do not add ads. User is configuring payment credentials. |
| President Advertising | `president/president_advertising_screen.dart` | None | No | Do not add ads to the ad management screen. |
| **ADMIN** | | | | |
| Admin Dashboard | `admin/admin_dashboard.dart` | Banner (top) | No | Current placement acceptable. |
| Apartments | `admin/apartments_screen.dart` | None | No | Low priority — admin tool. Skip. |
| Assign President | `admin/assign_president_screen.dart` | None | No | Do not add ads to admin management screens. |
| Create Apartment | `admin/create_apartment_screen.dart` | None | No | Do not add ads to admin management screens. |
| Ad Management | `admin/ad_management_screen.dart` | None | No | Do not add ads to the ad management screen. |
| Reports | `admin/reports_screen.dart` | None | View only | Low priority — admin tool. Skip. |
| **SHARED** | | | | |
| Community Screen | `shared/community_screen.dart` | Banner (top) | No | Current placement acceptable. |
| Payment Board | `shared/payment_board_screen.dart` | None | View only | Low priority — this tab is inside community_screen which already has a banner. Skip. |
| Notifications | `shared/notifications_screen.dart` | None | No | Add banner at bottom. Users visit regularly. |
| Chat Screen | `shared/chat_screen.dart` | None | No | Do not add ads to complaint message threads. This is used for urgent maintenance issues. |
| **AUTH (all screens)** | `auth/*.dart` | None | **Critical** | Correct. Do not add ads to any auth screen. |
| Splash | `splash_screen.dart` | None | **Critical** | Correct. |

**Summary:**
- Screens with current ads: **5**
- Screens where ads are suitable and currently absent: **8** (payment history, resident profile, monthly bill detail resident, community fund overview, fund transactions, manage users, president profile, notifications)
- Screens where ads must never appear: **9** (all auth screens, i-paid, create bill, edit bill, mark paid, add fund collection, add fund expense, upi settings, chat)
- Screens where ads are low priority or should be skipped: remaining

---

## D. TECHNICAL FINDINGS

### TF-01 — CRITICAL: Fixed Legacy Banner Size

**Issue ID:** TF-01  
**Severity:** High  
**File:** `lib/widgets/maintify_banner_ad.dart`, line 56  
**Class:** `_MaintifyBannerAdState._loadAd()`

**Evidence:**
```dart
_bannerAd = BannerAd(
  adUnitId: adUnitId,
  size: AdSize.banner,          // ← fixed 320×50 legacy size
  request: const AdRequest(),
  ...
```

**Root cause:** `AdSize.banner` creates a fixed 320×50 pixel banner regardless of device screen width. On modern Android devices with 360dp–430dp+ widths, this wastes 40–110dp of horizontal space that could serve a wider, higher-value ad.

**Google's current recommendation** (from `developers.google.com/admob/flutter/banner/anchored-adaptive`) is to use `AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width)` where width is derived from `MediaQuery.of(context).size.width`. This returns the optimal height for the given width and consistently outperforms fixed-size banners in both fill rate and eCPM.

**Impact of fixed size:**
- Lower eCPM (advertisers pay more for wider, more visible placements)
- Lower fill rate on devices where 320px is narrower than the screen
- Smaller visual footprint than available space

**Recommended correction:**
```dart
// In _MaintifyBannerAdState, add async _loadAd:
final width = MediaQuery.of(context).size.width.truncate();
final adSize = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
if (adSize == null) return;
_bannerAd = BannerAd(
  adUnitId: adUnitId,
  size: adSize,
  ...
);
```
The `SizedBox` dimensions must be updated to use the returned adaptive size's width/height.

**Expected revenue impact:** 20–40% increase in banner eCPM. Confidence: Medium.

---

### TF-02 — CRITICAL: No Google User Messaging Platform (UMP) Consent Flow

**Issue ID:** TF-02  
**Severity:** Critical (compliance and revenue)  
**Files:** No files — this feature is entirely absent from the codebase.

**Evidence:** Searched entire `lib/` directory for the following identifiers. Zero matches found:
- `UserMessagingPlatform`
- `ConsentInformation`
- `ConsentForm`
- `setRequestConfiguration`
- `tagForChildDirectedTreatment`
- `tagForUnderAgeOfConsent`
- `testDeviceIds`

**Root cause:** UMP was never implemented.

**Impact:**
1. **Compliance risk:** Google requires UMP for apps distributed in the EEA, UK, and Switzerland under GDPR. Failure to request consent may result in ad serving restrictions or policy enforcement. Even if the primary audience is India, apps on Google Play are globally distributed.
2. **Revenue impact:** Without a consent signal, Google defaults to non-personalized ads (NPA) for users in consent-required regions. NPA eCPM is typically 30–50% lower than personalized ad eCPM for the same placement.
3. **Limited ads mode:** Depending on account settings, missing consent may also trigger "Limited ads" (LAT) mode, which further reduces fill.

**Google's current implementation guide:**  
`developers.google.com/admob/flutter/privacy`

The standard pattern:
```dart
// In bootstrap(), after Firebase init, before MobileAds.instance.initialize():
await UMP.instance.requestConsentInfoUpdate(...);
if (UMP.instance.consentStatus == ConsentStatus.required) {
  await ConsentForm.loadAndShowConsentFormIfRequired(context);
}
await MobileAds.instance.initialize();
```

**Expected revenue impact:** High — enables personalized ads for consenting users. For primarily Indian traffic, the immediate impact may be small, but this is mandatory for compliance.

---

### TF-03 — HIGH: iOS Production AdMob App ID Not Configured

**Issue ID:** TF-03  
**Severity:** High  
**File:** `ios/inject_admob_id.sh`, line 22

**Evidence:**
```bash
PROD_ADMOB_APP_ID="ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX"  # TODO: replace
```

**Root cause:** The iOS Xcode Run Script phase that injects the AdMob App ID into `Info.plist` for production builds still contains the placeholder value. This means:
- Any iOS production build will use the placeholder App ID
- The iOS AdMob SDK will likely fail to initialize correctly
- No iOS revenue can be generated
- An iOS app submitted with an invalid App ID may be rejected or receive policy warnings

**Android is not affected** — `android/app/src/prod/AndroidManifest.xml` correctly contains `ca-app-pub-5097788367258292~4281310723`.

**Recommended correction:** Replace the placeholder in `ios/inject_admob_id.sh`:
```bash
PROD_ADMOB_APP_ID="ca-app-pub-5097788367258292~XXXXXXXXXX"  # Replace with real iOS App ID from AdMob console
```
Then also supply the iOS Ad Unit IDs via `--dart-define` flags at build time.

**Note:** If the app is currently Android-only in production, this is not causing current revenue loss. It must be fixed before an iOS release.

---

### TF-04 — MEDIUM: Interstitial Trigger Points Too Sparse

**Issue ID:** TF-04  
**Severity:** Medium  
**Files:** `lib/screens/resident/resident_dashboard.dart` line 77, `lib/screens/president/president_dashboard.dart` line 86

**Evidence:**
```dart
// Only location in resident_dashboard.dart:
InterstitialManager.instance.recordEligibleAction(
  config: ads.adConfig,
  apartmentAdsEnabled: ads.apartmentAdsEnabled,
);
// Called from: _onTabSelected (bottom nav tab switch only)
```

Interstitials fire only on **bottom-nav tab switches** in two dashboards. This produced 27 requests in 7 days — fewer than 4 per day.

**Root cause:** The interstitial frequency mechanism requires the user to reach the threshold count (`interstitialFrequency`) within a single session. If a user opens the app, checks one screen, and closes it without switching tabs the required number of times, no interstitial fires even though one was preloaded and loaded.

The 37% show rate (10 out of 27 loaded ads shown) is consistent with this: many loaded interstitials expire between sessions before the frequency threshold is met.

**Recommended correction:** Add `recordEligibleAction` calls on **navigation to key detail screens**:
- Navigating from bills list to bill detail
- Navigating from complaints list to complaint detail
- Opening the notifications screen
- Returning from bill detail to dashboard

This keeps triggers at natural navigation points without interrupting workflows. Avoid adding triggers on the same screen that handles payments.

---

### TF-05 — MEDIUM: No Test Device Configuration

**Issue ID:** TF-05  
**Severity:** Medium  
**Files:** No files — feature absent

**Evidence:** No `MobileAds.instance.updateRequestConfiguration` or `testDeviceIds` configuration found anywhere.

**Root cause:** Test device registration is not implemented.

**Impact:** When QA testers or developers use a production build (e.g. Play Store internal testing track), their interactions with real ads count toward AdMob metrics. If they repeatedly tap ads during testing, this can register as invalid traffic, which AdMob detects and may use to restrict ad serving or invalidate earnings.

**Recommended correction:**
```dart
// In AdMobService.initialize(), in debug builds only:
if (kDebugMode) {
  await MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(testDeviceIds: ['YOUR_HASHED_DEVICE_ID']),
  );
}
```
Device IDs can be found from AdMob SDK log output on first run.

---

### TF-06 — MEDIUM: Banner Placement at Screen Top on Bills Screen

**Issue ID:** TF-06  
**Severity:** Medium (UX and policy risk)  
**File:** `lib/screens/resident/bills_screen.dart`, line 46

**Evidence:**
```dart
Column(
  children: [
    const Padding(
      padding: EdgeInsets.only(top: 5),
      child: MaintifyBannerAd(),   // ← top of screen
    ),
    // Filter tabs and bills list below
```

**Root cause:** The banner is placed at the very top of the bills screen, immediately below the app bar.

**Risk:** Banners at the top of screens that contain interactive tabs or list items immediately below can generate accidental clicks. Users swiping down to access the tab bar or first list item may tap the ad unintentionally. Google's Better Ads Standards and AdMob policies prohibit ad placements that cause accidental clicks.

**Recommended correction:** Move the banner below the filter tabs:
```dart
Column(
  children: [
    // Filter tabs first
    PillFilterBar(...),
    const MaintifyBannerAd(),    // below tabs, above list
    Expanded(child: billsList),
  ],
)
```

Alternatively, place the banner at the bottom of the screen (outside the scrollable area) as an anchored banner.

---

### TF-07 — LOW: Banner `didChangeDependencies` Called on Every Ancestor Rebuild

**Issue ID:** TF-07  
**Severity:** Low  
**File:** `lib/widgets/maintify_banner_ad.dart`, lines 28–40

**Evidence:**
```dart
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  final ads = context.watch<AdsProvider>();
  ...
  if (enabled && _bannerAd == null) {
    _loadAd();
  }
```

**Root cause:** `didChangeDependencies` is called whenever any ancestor's `InheritedWidget` changes, not just when `AdsProvider` changes. The guard `_bannerAd == null` prevents duplicate loads, so this does not create duplicate ad requests. However, the extra calls add minor overhead and produce unnecessary log output.

**Impact:** Minimal. The existing guard is correct and functional. No duplicate requests are generated.

**Recommendation:** Low priority. No action required unless `debugPrint` logs become excessive in production. Consider switching to `Consumer<AdsProvider>` with an explicit change check for a cleaner implementation.

---

### TF-08 — LOW: `_actionCount` Resets Only on Dismissal, Not on Session End

**Issue ID:** TF-08  
**Severity:** Low  
**File:** `lib/core/ads/interstitial_manager.dart`, lines 29, 93, 131

**Evidence:**
```dart
int _actionCount = 0;
// Reset only in:
// (1) dispose() — called on logout
// (2) onAdDismissedFullScreenContent — after a successful show
```

**Root cause:** If the app is killed without an interstitial being shown and without logout, `_actionCount` resets to 0 on next cold start (singleton re-initializes). This means accumulated tab switches from a prior session do not carry over. This is acceptable behaviour for a singleton design — it is not a bug.

**Impact:** Negligible. If the user switches tabs 3 times, kills the app, and reopens it, the counter starts from 0. This slightly reduces interstitial frequency across sessions, but the cooldown mechanism (`interstitialCooldownSeconds`) already handles cross-session timing via `_lastShown` (which also resets on cold start).

**Recommendation:** No action required unless cross-session frequency tracking is desired.

---

### TF-09 — INFORMATIONAL: Android Production IDs Have Hardcoded Defaults

**Issue ID:** TF-09  
**Severity:** Informational  
**File:** `lib/core/ads/admob_config.dart`, lines 133, 143, 153, 163

**Evidence:**
```dart
androidAppId: String.fromEnvironment(
  'ADMOB_PROD_ANDROID_APP_ID',
  defaultValue: 'ca-app-pub-5097788367258292~4281310723',  // real ID in source
),
androidBannerAdUnitId: String.fromEnvironment(
  'ADMOB_PROD_ANDROID_BANNER_ID',
  defaultValue: 'ca-app-pub-5097788367258292/5961097598',  // real ID in source
),
```

**Root cause:** The Android production Ad Unit IDs are stored as `defaultValue` in `String.fromEnvironment()`. This means they are compiled into the binary regardless of whether `--dart-define` is passed. AdMob Ad Unit IDs are **not secrets** — they appear in network traffic and are visible to anyone who intercepts traffic or decompiles the APK. This is normal and expected for AdMob.

**Impact:** None. This is by design. The IDs are correct. The design avoids a build failure if `--dart-define` is not supplied for Android.

---

## E. POLICY AND COMPLIANCE AUDIT

### E.1 Google Mobile Ads SDK Initialization

**Status: PASS**  
`AdMobService.initialize()` correctly calls `MobileAds.instance.initialize()` after Firebase initialization in `bootstrap()` (`lib/main.dart` line 62). The initialization is wrapped in try/catch to prevent boot failures if AdMob SDK initialization fails. The service returns early on non-mobile platforms.

### E.2 User Consent / UMP

**Status: FAIL — Not implemented**  
See finding TF-02. This is the most significant compliance gap. Required before submission to markets where GDPR applies.

### E.3 Ad Unit Separation (Dev vs Production)

**Status: PASS**  
Development builds use Google's official hardcoded test IDs. Production builds use real IDs. The separation is enforced at the `AdMobConfig.current` level and cannot be bypassed by `--dart-define` in dev builds. This is correctly designed.

### E.4 Ad Placement Policy

**Status: PASS with one flag**  
No ads are placed on authentication screens, payment entry screens, or financial transaction screens. Ads appear only on informational views and dashboard screens. The one flag is the top-of-screen placement on `BillsScreen` (TF-06), which carries a minor accidental-click risk.

### E.5 Accidental Click Prevention

**Status: PARTIAL**  
The `BillsScreen` top-of-screen banner is adjacent to interactive filter tabs (TF-06). All other placements reviewed do not have interactive controls immediately adjacent to ad boundaries.

### E.6 app-ads.txt

**Status: PASS**  
File exists at `web/app-ads.txt`:
```
google.com, pub-5097788367258292, DIRECT, f08c47fec0942fa0
```
The publisher ID matches the production AdMob Ad Unit IDs in the codebase. The certification authority ID `f08c47fec0942fa0` is Google's standard public key. The file is in the Flutter web build output directory, which means it will be deployed to `https://maintify.web.app/app-ads.txt` as part of `flutter build web`. This is correct.

**Manual verification required:** Confirm the file is accessible at `https://maintify.web.app/app-ads.txt` without redirects or authentication. Google's crawler must be able to fetch it.

### E.7 Child-Directed Treatment

**Status: NOT CONFIGURED**  
No `tagForChildDirectedTreatment` or `tagForUnderAgeOfConsent` flags are set. For an apartment maintenance app targeting adult residents and apartment managers, this is acceptable — the app is not directed at children. However, it should be explicitly declared in the AdMob console under app settings.

### E.8 Data Safety Declaration (Google Play)

**Status: Cannot be verified from code**  
The Google Play Data Safety section must accurately reflect that the app uses Google AdMob, which may collect device identifiers, advertising ID, and approximate location for ad serving. This must be manually verified in the Play Console.

### E.9 Test Device Configuration

**Status: NOT CONFIGURED**  
See finding TF-05. No test device IDs registered. Risk of invalid traffic from testing on production builds.

### E.10 iOS ATT (App Tracking Transparency)

**Status: N/A — iOS not in production**  
iOS is not live (TF-03). When iOS is released, ATT permission (`NSUserTrackingUsageDescription` and `ATTrackingManager.requestTrackingAuthorization()`) must be implemented before AdMob initialization on iOS 14+.

---

## F. REVENUE ANALYSIS

### F.1 Baseline Data

Using the 7-day figures provided:

| Ad Unit | Requests | Matched | Impressions | Show Rate | eCPM | Earnings |
|---|---|---|---|---|---|---|
| Banner | 398 | 374 | 350 | 93.58% | $0.05 | $0.02 |
| Interstitial | 27 | 27 | 10 | 37.04% | $2.65 | $0.03 |
| **Total** | **425** | **401** | **360** | — | — | **$0.05** |

### F.2 Why Banner eCPM Is Low ($0.05)

The observed banner eCPM of $0.05 per 1,000 impressions is very low by global standards. The causes in approximate order of impact:

**1. Geographic market (primary cause).**  
India-tier eCPM for utility/productivity apps ranges from $0.04 to $0.35 depending on ad format and time of year. The $0.05 figure is consistent with Indian traffic on a fixed 320×50 banner. Indian eCPMs are structurally lower than US/EU markets due to advertiser demand. This cannot be changed by technical means.

**2. Fixed legacy banner size (secondary cause).**  
`AdSize.banner` (320×50) produces lower eCPM than adaptive banners. Adaptive banners are wider, more viewable, and attract higher bids. This is the most actionable technical improvement available.

**3. Missing UMP consent (tertiary cause).**  
Without a consent signal, Google may serve non-personalized ads to some users. NPA eCPM is lower than personalized eCPM. For primarily Indian traffic this effect is smaller than for EU traffic, but it still contributes.

**4. Ad unit history.**  
Newly created or recently reactivated ad units typically have lower eCPM because Google's auction system takes time to build performance signals. With 350 banner impressions in 7 days, the ad unit has minimal history.

**5. App category.**  
Apartment management utilities are a niche category with limited direct advertiser demand. eCPMs in utility apps are structurally lower than in entertainment, news, or gaming apps.

### F.3 Interstitial eCPM Analysis

The observed $2.65 interstitial eCPM is based on only 10 impressions. This sample is too small to be a reliable estimate. It is directionally consistent with Indian interstitial eCPMs (typical range $1.00–$5.00) but should not be used for forecasting until at least 500 impressions are recorded.

The 37% show rate is a revenue leak. Each preloaded but unshown interstitial is a wasted ad network request. See TF-04 for the fix.

### F.4 Impression Volume

51 average daily impressions across all formats is very low. At the current eCPM mix, reaching $1.00/day would require approximately 20,000 banner impressions or 377 interstitial impressions per day. This would require a DAU in the thousands, not the tens.

**The fundamental constraint is user volume, not ad configuration.** No amount of ad optimization will produce meaningful monthly revenue with 50 impressions per day.

---

## G. REVENUE OPTIMIZATION STRATEGY

### G.1 Fix the Adaptive Banner (Highest ROI per unit effort)

Upgrading `AdSize.banner` to adaptive banner in `MaintifyBannerAd` is a one-file change. It requires no new ad units, no Firestore changes, and no policy review. It is expected to increase banner eCPM by 20–40% and improve fill rate.

### G.2 Implement UMP Consent (Required for compliance and personalization)

Implementing Google UMP enables personalized ads for consenting users. For Indian-primary traffic, the immediate revenue impact is moderate (India has fewer consent-required users than EU). However, it is required for compliance and must be implemented before scaling to international markets.

### G.3 Add Banners to 4–5 Additional Screens (Medium effort, proportional impact)

The following screens are suitable for banner ads and have no policy or UX concerns:

| Screen | Expected additional impressions/day |
|---|---|
| `resident_profile_screen.dart` (bottom) | +8–15 |
| `payment_history_screen.dart` (bottom) | +5–10 |
| `monthly_bill_detail_screen.dart` resident (bottom) | +10–20 |
| `notifications_screen.dart` (bottom) | +5–10 |
| `community_fund_screen.dart` president (bottom) | +3–5 |

Estimated aggregate: +30–60 additional impressions per day, roughly doubling current banner impression volume, assuming the same DAU.

**Placement rule for all new banners:** Anchor to the bottom of the screen (outside any scrollable area) using `Scaffold.bottomNavigationBar` slot or a `Column` with `Spacer`. This prevents accidental clicks and ensures viewability.

### G.4 Expand Interstitial Trigger Points (Low effort, meaningful impact)

Add `recordEligibleAction` calls on:
- Navigating from bills list → bill detail (resident)
- Navigating from notification item → referenced screen
- Navigating from community tab → complaint detail

Do not add triggers on:
- Any financial entry screen
- Payment confirmation
- Complaint creation

Expected impact: 2–3× increase in interstitial requests. At current 100% match rate and even 50% show rate, this could add 20–40 more interstitial impressions per week.

### G.5 eCPM Floor Settings

Do not add manual eCPM floors at current impression volume. eCPM floors reduce fill rate and can cause total revenue to decrease when demand is thin. At fewer than 100 impressions per day, Google's automated optimization has insufficient data to manage floors effectively. Use default (no floors) and let Google optimize.

### G.6 Ad Mediation

Do not implement mediation at current traffic levels. Mediation (AdMob Bidding or waterfall) benefits publishers with significant daily impression volume (typically 10,000+). The integration cost and SDK size increase are not justified for the current ~50 impressions/day.

### G.7 Category Blocking

Review the AdMob console for category blocking. Blocking ad categories reduces the available demand pool and can lower eCPM and fill. Unless there is a specific policy or brand safety requirement to block categories, review any existing blocks and consider removing unnecessary ones.

---

## H. PRIORITIZED ACTION PLAN

### Immediate Fixes (Do First — High Impact, Low Risk)

| # | Action | File | Effort | Priority |
|---|---|---|---|---|
| H.1 | Fix iOS production AdMob App ID in `inject_admob_id.sh` | `ios/inject_admob_id.sh` line 22 | 5 min | Blocker for iOS |
| H.2 | Move `BillsScreen` banner below filter tabs | `lib/screens/resident/bills_screen.dart` | 15 min | Policy risk |

### Short-Term Improvements (High Revenue and Compliance Impact)

| # | Action | File | Effort | Priority |
|---|---|---|---|---|
| H.3 | Upgrade to adaptive banner in `MaintifyBannerAd` | `lib/widgets/maintify_banner_ad.dart` | 1 hour | High revenue |
| H.4 | Implement Google UMP consent flow | `lib/main.dart` + new consent service | 4–8 hours | Compliance critical |
| H.5 | Add banner to `resident_profile_screen.dart` (bottom) | `lib/screens/resident/resident_profile_screen.dart` | 30 min | Revenue |
| H.6 | Add banner to `payment_history_screen.dart` (bottom) | `lib/screens/resident/payment_history_screen.dart` | 30 min | Revenue |
| H.7 | Add banner to resident `monthly_bill_detail_screen.dart` (bottom) | `lib/screens/resident/monthly_bill_detail_screen.dart` | 30 min | Revenue |

### Medium-Term Improvements

| # | Action | File | Effort | Priority |
|---|---|---|---|---|
| H.8 | Add banner to `notifications_screen.dart` (bottom) | `lib/screens/shared/notifications_screen.dart` | 30 min | Revenue |
| H.9 | Add banner to `community_fund_screen.dart` president (bottom) | `lib/screens/president/community_fund_screen.dart` | 30 min | Revenue |
| H.10 | Expand interstitial triggers to bill detail and notification navigation | `resident_dashboard.dart`, `bills_screen.dart` | 1 hour | Revenue |
| H.11 | Register test device IDs in `AdMobService` | `lib/core/services/admob_service.dart` | 30 min | Compliance |

### Optional Future Enhancements

| # | Action | Effort | Prerequisite |
|---|---|---|---|
| H.12 | iOS AdMob Ad Unit ID setup and ATT integration | 1 day | iOS release readiness |
| H.13 | App Open Ad for cold start (if DAU grows to 1,000+) | 2 days | High DAU |
| H.14 | Firebase Analytics event tracking for ad placements | 1 day | Analytics setup |
| H.15 | Review and reduce AdMob category blocks in console | Manual | AdMob console access |
| H.16 | Native ad activation (Phase 3) | 1 hour | Admin approval |

---

## I. EXPECTED IMPACT

| Recommendation | Revenue Impact | UX Impact | Engineering Effort | Policy Risk | Confidence |
|---|---|---|---|---|---|
| H.3 Adaptive banner | High | Minimal — slightly taller ad | Low | None | Medium-High |
| H.4 UMP consent | High (long-term) | Moderate — adds consent dialog on first run | Medium | Reduces risk | High |
| H.5–H.9 New banners | Medium — proportional to screen visits | Low — anchored at bottom | Low | Low if placed at bottom | High |
| H.10 Interstitial triggers | Low–Medium | Low — natural navigation | Low | Low — natural transitions | Medium |
| H.11 Test device IDs | None (revenue) | None | Very Low | Reduces invalid traffic risk | High |
| H.1 iOS App ID | Unlocks iOS revenue | None | Very Low | None | High |
| H.2 Banner position | None (revenue) | Positive — reduces accidental taps | Very Low | Reduces risk | High |

**Important caveat:** All revenue projections at current impression volume are inherently low. The current ~51 impressions/day yields roughly $0.19/month. Doubling placements and upgrading to adaptive banner could increase this to approximately $0.40–$0.60/month. These figures are illustrative, not guaranteed. Meaningful advertising revenue at scale requires substantial DAU growth.

---

## J. TESTING REPORT

### Phase 1 — Code Inspection (Complete)

**Scope:** All files in `lib/` matching AdMob-related patterns, all native manifests, `pubspec.yaml`, `web/app-ads.txt`, `ios/inject_admob_id.sh`.

**Method:** Source code read + pattern search. No build or execution was performed.

**Files inspected:**

| File | Status |
|---|---|
| `lib/core/ads/ad_config.dart` | Inspected |
| `lib/core/ads/admob_config.dart` | Inspected |
| `lib/core/ads/admob_ids.dart` | Inspected |
| `lib/core/ads/interstitial_manager.dart` | Inspected |
| `lib/core/services/admob_service.dart` | Inspected |
| `lib/widgets/maintify_banner_ad.dart` | Inspected |
| `lib/widgets/maintify_native_ad.dart` | Inspected |
| `lib/providers/ads_provider.dart` | Inspected |
| `lib/main.dart` | Inspected |
| `lib/main_dev.dart` | Inspected |
| `lib/main_prod.dart` | Inspected |
| `lib/screens/dashboard_router.dart` | Inspected |
| `lib/screens/admin/ad_management_screen.dart` | Inspected |
| `lib/screens/admin/advertising_settings_screen.dart` | Inspected |
| `lib/screens/president/president_advertising_screen.dart` | Inspected |
| `lib/screens/resident/bills_screen.dart` | Inspected |
| `lib/screens/resident/resident_dashboard.dart` | Inspected |
| `lib/screens/president/president_dashboard.dart` | Inspected |
| `lib/screens/admin/admin_dashboard.dart` | Inspected |
| `lib/screens/shared/community_screen.dart` | Inspected |
| All other screens in `lib/screens/` | Inventoried for ad presence |
| `android/app/src/main/AndroidManifest.xml` | Inspected |
| `android/app/src/dev/AndroidManifest.xml` | Inspected |
| `android/app/src/prod/AndroidManifest.xml` | Inspected |
| `android/app/build.gradle.kts` | Inspected |
| `ios/Runner/Info.plist` | Inspected |
| `ios/inject_admob_id.sh` | Inspected |
| `pubspec.yaml` | Inspected |
| `web/app-ads.txt` | Inspected |

### Phase 2 — Build Testing

**Status: Not performed in this phase.**  
Build validation should be performed after implementing approved changes in Phase 4. Required tests:
- `flutter analyze` — zero errors
- `flutter build apk --flavor dev -t lib/main_dev.dart` — confirm test ads load
- `flutter build apk --flavor prod -t lib/main_prod.dart` — confirm production ad IDs (requires `--dart-define` flags)
- Adaptive banner rendering on multiple device sizes
- UMP consent dialog display (if H.4 is approved)
- Interstitial show/dismiss cycle on physical Android device

### Phase 3 — Runtime / AdMob Console

**Status: Cannot be performed without account access.**  
The following items require manual verification in the AdMob console and Play Console:
- Ad unit serving status (not restricted)
- Policy center — no active violations
- `app-ads.txt` verification status in AdMob
- Test device registration
- Data safety section accuracy in Play Console
- Category blocks review

### Remaining Limitations

- AdMob console account data was not directly accessible during this audit. All revenue figures are from the provided baseline screenshots.
- Google sellers.json publisher visibility was not verified (requires external HTTP check to `https://storage.googleapis.com/app-ads-txt/google.json`).
- iOS build was not tested — TF-03 is based on source code inspection only.
- Real eCPM variability, country distribution, and device distribution data were not available.

---

## APPENDIX: AD UNIT QUICK REFERENCE

| Ad Unit | Platform | Environment | ID |
|---|---|---|---|
| Banner | Android | Production | `ca-app-pub-5097788367258292/5961097598` |
| Banner | Android | Development | `ca-app-pub-3940256099942544/6300978111` |
| Banner | iOS | Production | Not configured |
| Banner | iOS | Development | `ca-app-pub-3940256099942544/2934735716` |
| Interstitial | Android | Production | `ca-app-pub-5097788367258292/5825366227` |
| Interstitial | Android | Development | `ca-app-pub-3940256099942544/1033173712` |
| Interstitial | iOS | Production | Not configured |
| Interstitial | iOS | Development | `ca-app-pub-3940256099942544/4411468910` |
| Native | Android | Production | `ca-app-pub-5097788367258292/7956705545` (disabled) |
| Native | Android | Development | `ca-app-pub-3940256099942544/2247696110` (disabled) |

**AdMob Publisher ID:** `pub-5097788367258292`  
**Android App ID (Production):** `ca-app-pub-5097788367258292~4281310723`  
**iOS App ID (Production):** To be configured in `ios/inject_admob_id.sh`

---

*End of report. This document covers Phase 1 (inspection) and Phase 2 (findings). No code modifications were made. All recommendations require explicit approval before implementation.*
