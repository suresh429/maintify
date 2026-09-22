import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// ── Data types ────────────────────────────────────────────────────────────────

/// Which URI scheme the app uses to receive UPI payment intents.
///
/// - [standard] → `upi://pay?...`   (NPCI UPI deep-link spec)
/// - [phonePe]  → `ppe://pay?...`   (PhonePe proprietary fallback,
///   confirmed working on Android 16 Realme devices where PhonePe does not
///   register to the generic `upi://` intent)
enum UpiScheme { standard, phonePe }

/// A UPI-capable app discovered on the device.
class UpiApp {
  final String packageName;
  final String appName;
  final UpiScheme scheme;

  const UpiApp({
    required this.packageName,
    required this.appName,
    required this.scheme,
  });

  @override
  String toString() => 'UpiApp($appName / $packageName / ${scheme.name})';
}

/// Parameters for a UPI payment request.
class UpiPaymentParams {
  final String upiId;
  final String payeeName;
  final double amount;
  /// Short transaction note shown in the UPI app (≤ 50 chars recommended).
  final String txnNote;

  const UpiPaymentParams({
    required this.upiId,
    required this.payeeName,
    required this.amount,
    required this.txnNote,
  });
}

/// Result of a UPI launch attempt.
enum UpiLaunchResult {
  /// Intent fired — UPI app opened (does NOT mean payment succeeded).
  launched,
  /// No matching app / ActivityNotFoundException.
  noAppFound,
  /// Non-Android / web platform.
  unsupportedPlatform,
  /// Unexpected error (see debug log).
  error,
}

// ── UpiLauncher ───────────────────────────────────────────────────────────────

/// Native Android bridge for UPI payment intent discovery and launching.
///
/// All Android interaction goes through the [_channel] MethodChannel;
/// iOS/web code paths return safe defaults without crashing.
///
/// Payment security note: launching a UPI app does NOT confirm payment.
/// After the app returns, the resident must submit a UPI transaction reference
/// and the president must verify it before the bill is marked paid.
class UpiLauncher {
  const UpiLauncher._();

  static const UpiLauncher instance = UpiLauncher._();

  static const _channel = MethodChannel('com.maintify.upi/launcher');

  bool get isAndroid {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  // ── Discovery ─────────────────────────────────────────────────────────────

  /// Returns the list of UPI-capable apps installed on this Android device.
  ///
  /// Discovery strategy (implemented in [MainActivity]):
  ///   1. QueryIntentActivities for `upi://pay` → standard apps (GPay, Paytm, BHIM, …)
  ///   2. If PhonePe (`com.phonepe.app`) is installed but not in the standard list,
  ///      add it with [UpiScheme.phonePe] so it is launched via `ppe://pay`.
  ///
  /// Returns `[]` on non-Android platforms.
  Future<List<UpiApp>> getAvailableApps() async {
    if (!isAndroid) return [];

    try {
      final rawList =
          await _channel.invokeMethod<List<dynamic>>('getAvailableUpiApps');
      if (rawList == null) return [];

      final apps = <UpiApp>[];
      for (final raw in rawList) {
        final map = Map<String, dynamic>.from(raw as Map);
        final scheme = (map['scheme'] as String?) == 'phonePe'
            ? UpiScheme.phonePe
            : UpiScheme.standard;
        apps.add(UpiApp(
          packageName: (map['packageName'] as String?) ?? '',
          appName: (map['appName'] as String?) ?? 'UPI App',
          scheme: scheme,
        ));
      }
      debugPrint('[UPI] Discovery found ${apps.length} app(s): ${apps.map((a) => a.appName).join(', ')}');
      return apps;
    } on PlatformException catch (e) {
      debugPrint('[UPI] Discovery PlatformException — ${e.code}: ${e.message}');
      return [];
    } on MissingPluginException {
      debugPrint('[UPI] Discovery MissingPluginException — rebuild required');
      return [];
    } catch (e) {
      debugPrint('[UPI] Discovery unexpected error: $e');
      return [];
    }
  }

  // ── Launching ─────────────────────────────────────────────────────────────

  /// Opens [app] with [params] via Android ACTION_VIEW.
  ///
  /// - [UpiScheme.standard]  → `upi://pay?pa=…&pn=…&am=…&cu=INR&tn=…`
  /// - [UpiScheme.phonePe]   → `ppe://pay?pa=…&pn=…&am=…&cu=INR&tn=…`
  ///
  /// URI construction is done on the Kotlin side with [Uri.Builder] for
  /// safe, spec-compliant percent-encoding (no `+` encoding).
  ///
  /// Returns [UpiLaunchResult.launched] on success; never throws.
  Future<UpiLaunchResult> launchApp(
    UpiApp app,
    UpiPaymentParams params,
  ) async {
    if (!isAndroid) return UpiLaunchResult.unsupportedPlatform;

    debugPrint(
      '[UPI] Launch → app=${app.appName} scheme=${app.scheme.name} '
      'am=${params.amount.toStringAsFixed(2)} tn=${params.txnNote}',
    );

    try {
      final launched = await _channel.invokeMethod<bool>('launchUpi', {
        'upiId': params.upiId,
        'payeeName': params.payeeName,
        'amount': params.amount.toStringAsFixed(2),
        'txnNote': params.txnNote,
        'scheme': app.scheme.name, // 'standard' | 'phonePe'
      });

      if (launched == true) {
        debugPrint('[UPI] Intent launched successfully for ${app.appName}');
        return UpiLaunchResult.launched;
      } else {
        debugPrint('[UPI] startActivity returned false for ${app.appName}');
        return UpiLaunchResult.noAppFound;
      }
    } on PlatformException catch (e) {
      debugPrint('[UPI] PlatformException for ${app.appName} — ${e.code}: ${e.message}');
      return UpiLaunchResult.noAppFound;
    } on MissingPluginException {
      debugPrint('[UPI] MissingPluginException — run flutter run to recompile native code');
      return UpiLaunchResult.error;
    } catch (e) {
      debugPrint('[UPI] Unexpected error for ${app.appName}: $e');
      return UpiLaunchResult.error;
    }
  }

  /// Attempts a generic `upi://pay` intent without targeting a specific app.
  /// Use as a last-resort fallback — the OS may show an app chooser or
  /// return [UpiLaunchResult.noAppFound] if nothing handles the intent.
  Future<UpiLaunchResult> launchGeneric(UpiPaymentParams params) {
    return launchApp(
      const UpiApp(packageName: '', appName: 'UPI', scheme: UpiScheme.standard),
      params,
    );
  }
}

// ── Legacy adapter (kept for any code referencing DirectUpiPaymentService) ───

/// @deprecated Use [UpiLauncher.instance] instead.
@Deprecated('Use UpiLauncher.instance')
class DirectUpiPaymentService {
  const DirectUpiPaymentService();

  Future<UpiLaunchResult> initiatePayment(UpiPaymentParams params) {
    return UpiLauncher.instance.launchGeneric(params);
  }
}
