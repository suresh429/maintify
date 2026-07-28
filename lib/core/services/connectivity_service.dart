import 'dart:async';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

/// Singleton that wraps [InternetConnection] from
/// internet_connection_checker_plus.
///
/// Responsibilities
/// ─────────────────
/// • Maintain a synchronous cached [isConnected] flag (updated from the
///   stream) so provider action methods can do a cheap guard-check without
///   awaiting a DNS probe.
/// • Expose [onStatusChange] so [ConnectivityProvider] can subscribe and
///   drive the global UI banner.
/// • Expose [checkNow] for an on-demand probe (used at startup).
///
/// Only ONE stream subscription lives here — [ConnectivityProvider]
/// creates its own subscription for notifyListeners(), keeping
/// responsibilities separated.
class ConnectivityService {
  ConnectivityService._() {
    _initCache();
  }

  static final ConnectivityService instance = ConnectivityService._();

  final InternetConnection _checker = InternetConnection();
  StreamSubscription<InternetStatus>? _cacheSub;

  /// Optimistic default — corrected asynchronously within milliseconds.
  bool _isConnected = true;

  /// Synchronous cached state.
  /// Use this for quick guards in provider action methods (no async overhead).
  bool get isConnected => _isConnected;
  bool get isDisconnected => !_isConnected;

  /// Broadcast stream of status changes.
  /// Multiple subscribers are safe — they all share the same underlying
  /// poll cycle.
  Stream<InternetStatus> get onStatusChange => _checker.onStatusChange;

  /// Forces an immediate DNS probe and returns the result.
  /// Also updates the cached [isConnected].
  Future<bool> checkNow() async {
    _isConnected = await _checker.hasInternetAccess;
    return _isConnected;
  }

  void _initCache() {
    // Resolve real state on startup without blocking.
    _checker.hasInternetAccess.then((v) => _isConnected = v);
    // Keep cached value in sync with every subsequent change.
    _cacheSub = _checker.onStatusChange.listen(
      (status) => _isConnected = status == InternetStatus.connected,
    );
  }

  /// Call this if ConnectivityService itself needs to be torn down (rare).
  void dispose() {
    _cacheSub?.cancel();
  }
}
