import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../navigation_key.dart';
import 'firestore_service.dart';

/// Handles Firebase Cloud Messaging — permission requests, token lifecycle,
/// foreground/background message callbacks, and notification-tap navigation.
///
/// Design notes:
/// - Singleton: only one instance ever exists.
/// - `init()` is safe to call multiple times (re-login). An `_initialized`
///   guard ensures that stream listeners (`onMessage`, `onMessageOpenedApp`,
///   `onTokenRefresh`) are registered exactly once for the lifetime of the
///   process. Re-calling `init()` only refreshes/saves the token.
/// - `_activeUserId` is updated on every `init()` call so `onTokenRefresh`
///   always writes to the current user's Firestore document, not a stale one
///   from a previous session.
class FcmService {
  static final FcmService _instance = FcmService._();
  factory FcmService() => _instance;
  FcmService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirestoreService _fs = FirestoreService();

  bool _initialized = false;
  String? _activeUserId;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Call once after every successful login.
  ///
  /// Requests notification permission (Android 13+ / iOS), fetches + saves
  /// the FCM token to `users/{userId}/fcmToken`, and — on the very first
  /// call — registers the long-lived stream listeners.
  Future<void> init(String userId) async {
    _activeUserId = userId;

    // 1. Request permission ─────────────────────────────────────────────────
    await _requestPermission();

    // 2. Save token to Firestore ────────────────────────────────────────────
    await _saveToken(userId);

    // 3. Register one-time listeners ────────────────────────────────────────
    if (_initialized) return;
    _initialized = true;

    // Token refresh: FCM may rotate the token; always keep Firestore up to date.
    _messaging.onTokenRefresh.listen((newToken) {
      final uid = _activeUserId;
      if (uid == null) return;
      if (kDebugMode) {
        debugPrint('[FCM] Token refreshed for $uid: ${newToken.substring(0, 20)}…');
      }
      _fs.updateUser(uid, {'fcmToken': newToken}).catchError((e) {
        if (kDebugMode) debugPrint('[FCM] Token refresh save error: $e');
      });
    });

    // Foreground: the app is open when the message arrives.
    // On iOS, `setForegroundNotificationPresentationOptions` makes FCM show
    // a system banner even while the app is in the foreground.
    // On Android, foreground messages do NOT show a system notification by
    // default — the in-app badge via NotificationProvider handles visibility.
    if (Platform.isIOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    FirebaseMessaging.onMessage.listen((message) {
      if (kDebugMode) {
        debugPrint('[FCM] Foreground message received'
            ' — title: ${message.notification?.title}'
            ' | body: ${message.notification?.body}'
            ' | data: ${message.data}');
      }
      // In-app notification badge / list is updated via the Firestore stream
      // in NotificationProvider — no additional action needed here.
    });

    // Background: app is running but not in the foreground — user tapped notification.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (kDebugMode) {
        debugPrint('[FCM] onMessageOpenedApp (background tap): ${message.data}');
      }
      _handleTap(message);
    });

    // Terminated: app was fully closed — the notification launch opened it.
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      if (kDebugMode) {
        debugPrint('[FCM] getInitialMessage (terminated tap): ${initial.data}');
      }
      // Delay until the navigator widget tree is mounted.
      Future.delayed(const Duration(milliseconds: 600), () => _handleTap(initial));
    }
  }

  /// Returns the current FCM token. Useful for manual debug verification.
  Future<String?> getToken() => _messaging.getToken();

  // ── Permission ────────────────────────────────────────────────────────────

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (kDebugMode) {
      debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint(
            '[FCM] ⚠ Notifications DENIED. '
            'On Android 13+, ensure POST_NOTIFICATIONS is in AndroidManifest '
            'and the user accepted the runtime dialog. '
            'On iOS, open Settings → Notifications → Maintify and enable.');
      }
    }
  }

  // ── Token ─────────────────────────────────────────────────────────────────

  Future<void> _saveToken(String userId) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) {
        if (kDebugMode) {
          debugPrint('[FCM] ⚠ getToken() returned null for $userId. '
              'Possible causes: no internet, Play Services missing, '
              'or google-services.json mismatch.');
        }
        return;
      }

      await _fs.updateUser(userId, {'fcmToken': token});

      if (kDebugMode) {
        debugPrint('[FCM] Token saved for $userId');
        debugPrint('[FCM] Token (first 40 chars): ${token.substring(0, token.length.clamp(0, 40))}…');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[FCM] ✗ _saveToken error for $userId: $e');
      }
    }
  }

  // ── Tap navigation ────────────────────────────────────────────────────────

  /// Navigates to the relevant screen when a notification is tapped.
  /// The Cloud Function attaches a `type` field in `message.data` for routing.
  void _handleTap(RemoteMessage message) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      if (kDebugMode) debugPrint('[FCM] _handleTap: navigator not ready yet.');
      return;
    }

    final type = message.data['type'] as String?;
    if (kDebugMode) debugPrint('[FCM] Notification tapped — type: $type');

    // Navigate to the dashboard; DashboardRouter shows the role-correct view.
    // The user can then drill into the relevant screen (bills, complaints, etc.).
    navigator.pushNamedAndRemoveUntil('/dashboard', (route) => false);
  }
}
