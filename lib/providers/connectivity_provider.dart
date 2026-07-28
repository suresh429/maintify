import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import '../core/services/connectivity_service.dart';

/// Global connectivity state provider — exactly ONE instance lives in the
/// root [MultiProvider].
///
/// Responsibilities
/// ─────────────────
/// • Subscribe to [ConnectivityService.onStatusChange].
/// • Cache current state as [isConnected] / [isDisconnected].
/// • Call [notifyListeners] on every status change so
///   [GlobalConnectivityOverlay] can update the banner.
///
/// No UI logic lives here.
/// No screen should subscribe to this provider directly — only
/// [GlobalConnectivityOverlay] consumes it.
class ConnectivityProvider extends ChangeNotifier {
  ConnectivityProvider() {
    _init();
  }

  final ConnectivityService _service = ConnectivityService.instance;
  StreamSubscription<InternetStatus>? _subscription;

  /// Mirrors ConnectivityService's optimistic default; corrected in [_init].
  bool _isConnected = true;

  /// true  → device has verified internet access.
  /// false → offline, captive portal, or no route to internet.
  bool get isConnected => _isConnected;
  bool get isDisconnected => !_isConnected;

  Future<void> _init() async {
    // Perform an immediate DNS probe to correct the optimistic default.
    _isConnected = await _service.checkNow();
    notifyListeners();

    // Subscribe to all subsequent changes.
    _subscription = _service.onStatusChange.listen((status) {
      final connected = status == InternetStatus.connected;
      if (connected == _isConnected) return; // No change — skip rebuild.
      _isConnected = connected;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
