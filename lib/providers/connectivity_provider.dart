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
/// • Debounce status changes before calling [notifyListeners] to eliminate
///   banner spam from transient network fluctuations.
/// • Call [notifyListeners] only on real transitions so
///   [GlobalConnectivityOverlay] updates once per event.
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
  Timer? _debounce;

  /// How long to wait before declaring the device offline.
  /// A 2.5 s window absorbs Wi-Fi frequency switches, DHCP renewals, and
  /// brief DNS timeouts without showing the banner.
  static const _offlineDebounce = Duration(milliseconds: 2500);

  /// Reconnection is confirmed quickly — 500 ms is enough to filter duplicate
  /// "connected" events that some platforms emit on interface changes.
  static const _onlineDebounce = Duration(milliseconds: 500);

  /// Optimistic default — corrected by the first stream event.
  bool _isConnected = true;

  /// true  → device has verified internet access.
  /// false → offline, captive portal, or no route to internet.
  bool get isConnected => _isConnected;
  bool get isDisconnected => !_isConnected;

  void _init() {
    // Subscribe to status changes with asymmetric debounce:
    //   • Going offline  → wait 2.5 s before reacting (avoids false positives)
    //   • Coming online  → wait 0.5 s before reacting (filters duplicate events)
    _subscription = _service.onStatusChange.listen((status) {
      final connected = status == InternetStatus.connected;
      _debounce?.cancel();
      _debounce = Timer(
        connected ? _onlineDebounce : _offlineDebounce,
        () {
          if (connected == _isConnected) return; // already in this state
          _isConnected = connected;
          notifyListeners();
        },
      );
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
