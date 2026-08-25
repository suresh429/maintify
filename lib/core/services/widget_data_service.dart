import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Pushes Maintify data to the iOS shared App Group so the native
/// MaintifyWidget extension can display it on the Home Screen.
///
/// All methods are no-ops on Android and web — safe to call from shared code.
class WidgetDataService {
  static const _channel = MethodChannel('com.maintify.app/widget');

  /// Writes authenticated widget data and triggers a WidgetKit timeline reload.
  /// [pendingBillCount] means "bills due" for residents, "flats pending" for presidents.
  static Future<void> update({
    required bool isLoggedIn,
    String? apartmentName,
    String? residentName,
    String? userRole,
    int pendingBillCount = 0,
    String? pendingAmountDisplay,
  }) async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('updateWidgetData', {
        'isLoggedIn': isLoggedIn,
        'apartmentName': apartmentName ?? '',
        'residentName': residentName ?? '',
        'userRole': userRole ?? '',
        'pendingBillCount': pendingBillCount,
        'pendingAmount': pendingAmountDisplay ?? '',
        'lastUpdated': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Widget updates are non-critical — never crash the main app.
      debugPrint('[Widget] update failed (non-critical): $e');
    }
  }

  /// Clears widget data and shows the logged-out state.
  /// Call this on logout or session expiry.
  static Future<void> clear() async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('clearWidgetData');
    } catch (e) {
      debugPrint('[Widget] clear failed (non-critical): $e');
    }
  }
}
