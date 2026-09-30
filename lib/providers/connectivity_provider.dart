import 'dart:async';
import 'package:flutter/widgets.dart';
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
/// • Suppress false offline/online events triggered by Android screen-on and
///   app-resume lifecycle transitions (DNS probe fires before network is ready).
/// • Call [notifyListeners] only on real transitions so
///   [GlobalConnectivityOverlay] updates once per event.
///
/// No UI logic lives here.
/// No screen should subscribe to this provider directly — only
/// [GlobalConnectivityOverlay] consumes it.
class ConnectivityProvider extends ChangeNotifier with WidgetsBindingObserver {
  ConnectivityProvider() {
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  final ConnectivityService _service = ConnectivityService.instance;
  StreamSubscription<InternetStatus>? _subscription;
  Timer? _debounce;
  Timer? _suppressionTimer;

  /// How long to wait before declaring the device offline.
  static const _offlineDebounce = Duration(milliseconds: 2500);

  /// Reconnection is confirmed quickly.
  static const _onlineDebounce = Duration(milliseconds: 500);

  /// Startup suppression: silence the first N seconds so the initial DNS probe
  /// result establishes state quietly without showing any banner.
  static const _startupSuppression = Duration(seconds: 3);

  /// Resume suppression: when the app returns to foreground, the DNS poller
  /// may fire immediately with a stale/transient result. Hold off for 4 s,
  /// then do a confirmed probe and notify only if state genuinely changed.
  static const _resumeSuppression = Duration(seconds: 4);

  /// While [_suppressed] is true, stream events update [_isConnected] silently
  /// (no debounce, no [notifyListeners]).
  bool _suppressed = true;

  /// Connectivity state at the moment a suppression window opens.
  /// Used on resume to decide whether state actually changed.
  bool _stateAtSuppressStart = true;

  /// Generation counter — incremented each time a suppression window opens.
  /// Allows the async [checkNow] callback to detect if a newer suppression
  /// window has since started and discard stale results.
  int _suppressionGeneration = 0;

  /// Optimistic default — corrected silently during startup suppression.
  bool _isConnected = true;

  /// true  → device has verified internet access.
  /// false → offline, captive portal, or no route to internet.
  bool get isConnected => _isConnected;
  bool get isDisconnected => !_isConnected;

  void _init() {
    debugPrint('[CONNECTIVITY] init — starting ${_startupSuppression.inSeconds}s startup suppression');

    // Subscribe to status changes.
    _subscription = _service.onStatusChange.listen(_onStatusEvent);

    // Startup suppression window: silently establish the real connectivity
    // state, then lift suppression without notifying (we show no banner on
    // first open regardless of state).
    final startGeneration = ++_suppressionGeneration;
    _suppressionTimer?.cancel();
    _suppressionTimer = Timer(_startupSuppression, () async {
      if (_suppressionGeneration != startGeneration) return; // stale
      debugPrint('[CONNECTIVITY] Startup suppression ended — probing…');
      try {
        final confirmed = await _service.checkNow();
        if (_suppressionGeneration != startGeneration) return; // stale
        debugPrint('[CONNECTIVITY] Startup probe result: ${confirmed ? "online" : "offline"}');
        _isConnected = confirmed;
        // No notifyListeners — we never show a banner on cold start.
      } catch (e) {
        debugPrint('[CONNECTIVITY] Startup probe error: $e');
      } finally {
        if (_suppressionGeneration == startGeneration) {
          _suppressed = false;
          debugPrint('[CONNECTIVITY] Suppression lifted — live monitoring active');
        }
      }
    });
  }

  void _onStatusEvent(InternetStatus status) {
    final connected = status == InternetStatus.connected;
    debugPrint('[CONNECTIVITY] Stream event: ${connected ? "connected" : "disconnected"} (suppressed=$_suppressed)');

    if (_suppressed) {
      // During suppression: silently track state, no debounce, no notification.
      _isConnected = connected;
      debugPrint('[CONNECTIVITY] Suppressed — state updated silently to ${connected ? "online" : "offline"}');
      return;
    }

    // Normal live monitoring: asymmetric debounce.
    _debounce?.cancel();
    _debounce = Timer(
      connected ? _onlineDebounce : _offlineDebounce,
      () {
        if (connected == _isConnected) {
          debugPrint('[CONNECTIVITY] Debounce fired but state unchanged (${connected ? "online" : "offline"}) — skipping');
          return;
        }
        debugPrint('[CONNECTIVITY] Notifying: transition to ${connected ? "ONLINE" : "OFFLINE"}');
        _isConnected = connected;
        notifyListeners();
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Cancel any pending debounce so a stale timer doesn't fire when the
      // app resumes (which would show a spurious banner).
      _debounce?.cancel();
      _debounce = null;
      debugPrint('[CONNECTIVITY] App paused — debounce cancelled');
    } else if (state == AppLifecycleState.resumed) {
      _onResume();
    }
  }

  void _onResume() {
    debugPrint('[CONNECTIVITY] App resumed — starting ${_resumeSuppression.inSeconds}s suppression window');
    _stateAtSuppressStart = _isConnected;
    _suppressed = true;
    _debounce?.cancel();
    _suppressionTimer?.cancel();

    final resumeGeneration = ++_suppressionGeneration;

    _suppressionTimer = Timer(_resumeSuppression, () async {
      if (_suppressionGeneration != resumeGeneration) return; // stale
      debugPrint('[CONNECTIVITY] Resume suppression ended — probing…');
      try {
        final confirmed = await _service.checkNow();
        if (_suppressionGeneration != resumeGeneration) return; // stale
        debugPrint('[CONNECTIVITY] Resume probe: ${confirmed ? "online" : "offline"} (was: ${_stateAtSuppressStart ? "online" : "offline"})');
        _isConnected = confirmed;
        if (confirmed != _stateAtSuppressStart) {
          debugPrint('[CONNECTIVITY] Genuine state change on resume — notifying');
          notifyListeners();
        } else {
          debugPrint('[CONNECTIVITY] State unchanged on resume — no notification');
        }
      } catch (e) {
        debugPrint('[CONNECTIVITY] Resume probe error: $e');
        // On probe error assume state unchanged — keep _isConnected as-is.
      } finally {
        if (_suppressionGeneration == resumeGeneration) {
          _suppressed = false;
          debugPrint('[CONNECTIVITY] Resume suppression lifted');
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _suppressionTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}
