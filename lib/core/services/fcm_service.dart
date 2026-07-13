import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../navigation_key.dart';
import 'firestore_service.dart';

/// Handles Firebase Cloud Messaging — permission, token lifecycle,
/// foreground/background message callbacks, and notification-tap navigation.
///
/// Design notes:
/// - Singleton: only one instance ever exists.
/// - `init()` is safe to call multiple times (re-login). `_initialized` ensures
///   listeners are registered exactly once per process.
/// - `_activeUserId` is updated on every `init()` so `onTokenRefresh` always
///   writes to the current user's Firestore doc, not a stale one.
class FcmService {
  static final FcmService _instance = FcmService._();
  factory FcmService() => _instance;
  FcmService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirestoreService _fs = FirestoreService();
  final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _activeUserId;

  // Must match AndroidManifest meta-data:
  // com.google.firebase.messaging.default_notification_channel_id
  static const _channelId = 'fcm_fallback_notification_channel';
  static const _channelName = 'Maintify Notifications';

  // ── Public API ────────────────────────────────────────────────────────────

  /// Call once after every successful login.
  Future<void> init(String userId) async {
    _activeUserId = userId;
    // ignore: avoid_print
    print('[FCM] init() called for $userId (initialized=$_initialized)');

    // 1. Request permission (Android 13+ / iOS)
    await _requestPermission();

    // 2. Save token to Firestore + print full token
    await _saveToken(userId);

    // 3. One-time listeners
    if (_initialized) return;
    _initialized = true;

    // 4. Init flutter_local_notifications for Android foreground banners
    await _initLocalNotifications();

    // Token rotation — FCM may issue a new token; keep Firestore up to date
    _messaging.onTokenRefresh.listen((newToken) {
      final uid = _activeUserId;
      if (uid == null) return;
      // ignore: avoid_print
      print('╔══ FCM TOKEN REFRESHED (user: $uid) ══╗');
      // ignore: avoid_print
      print('║  $newToken');
      // ignore: avoid_print
      print('╚══════════════════════════════════════╝');
      _fs.updateUser(uid, {'fcmToken': newToken}).catchError((e) {
        debugPrint('[FCM] Token refresh save error: $e');
      });
    });

    // iOS: show system banner while app is in foreground
    if (Platform.isIOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // Foreground messages
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('[FCM] Foreground — title: ${message.notification?.title}'
          ' | body: ${message.notification?.body}'
          ' | type: ${message.data["type"]}');
      // Android: FCM does NOT show a system banner in foreground — show one
      // manually via flutter_local_notifications.
      // iOS: handled natively via setForegroundNotificationPresentationOptions.
      if (Platform.isAndroid) {
        _showLocalNotification(message);
      }
    });

    // Background tap (app running, not in foreground)
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('[FCM] Background tap: ${message.data}');
      _handleTap(message);
    });

    // Terminated tap (app was fully closed)
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      debugPrint('[FCM] Terminated tap: ${initial.data}');
      Future.delayed(
        const Duration(milliseconds: 600),
        () => _handleTap(initial),
      );
    }
  }

  /// Returns the current FCM token (full string). Use in FcmDebugScreen.
  Future<String?> getToken() => _messaging.getToken();

  // ── Local notifications (Android foreground) ──────────────────────────────

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const settings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _localNotif.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('[FCM] Local notification tapped: payload=${details.payload}');
        // Navigate to dashboard when user taps a local (foreground) notification
        navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/dashboard', (r) => false);
      },
    );

    // Create the Android notification channel (no-op if it already exists)
    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: 'Apartment alerts and updates from Maintify',
            importance: Importance.high,
            playSound: true,
          ),
        );

    debugPrint('[FCM] Local notifications initialised (channel: $_channelId)');
  }

  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotif.show(
      // Use notification.hashCode as a cheap unique ID
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          icon: '@mipmap/ic_launcher',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
      ),
      payload: message.data['type'],
    );
  }

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

    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[FCM] ⚠ Notifications DENIED. '
          'Android 13+: ensure POST_NOTIFICATIONS in AndroidManifest and '
          'user accepted runtime dialog. iOS: Settings → Notifications → Maintify.');
    }
  }

  // ── Token ─────────────────────────────────────────────────────────────────

  Future<void> _saveToken(String userId) async {
    // ignore: avoid_print
    print('[FCM] _saveToken START for $userId');
    try {
      // iOS: getToken() fails if APNS token isn't assigned yet
      if (Platform.isIOS) {
        final apnsToken = await _messaging.getAPNSToken();
        if (apnsToken == null) {
          // ignore: avoid_print
          print('[FCM] ⚠ APNS token not ready — skipping');
          return;
        }
      }

      // getToken() can hang on some devices — apply a 10-second timeout.
      // ignore: avoid_print
      print('[FCM] Calling getToken()…');
      final token = await _messaging.getToken().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          // ignore: avoid_print
          print('[FCM] ⚠ getToken() timed out after 10s — check network / Play Services');
          return null;
        },
      );

      if (token == null) {
        // ignore: avoid_print
        print('[FCM] ⚠ getToken() returned null. '
            'Causes: no internet, Play Services issue, or google-services.json mismatch.');
        return;
      }

      // ── Print FULL token FIRST (before Firestore write that could fail) ──
      // ignore: avoid_print
      print('╔══════════════════════════════════════════════════════╗');
      // ignore: avoid_print
      print('║  FCM TOKEN  (user: $userId)');
      // ignore: avoid_print
      print('║  $token');
      // ignore: avoid_print
      print('╚══════════════════════════════════════════════════════╝');

      // Save token to Firestore (non-blocking for the print above)
      await _fs.updateUser(userId, {'fcmToken': token});
      // ignore: avoid_print
      print('[FCM] Token saved to Firestore ✓');
    } catch (e) {
      // ignore: avoid_print
      print('[FCM] ✗ _saveToken error for $userId: $e');
    }
  }

  // ── Tap navigation ────────────────────────────────────────────────────────

  /// Routes to the appropriate screen when a push notification is tapped.
  ///
  /// Cloud Functions attach a `type` field in `message.data`:
  ///   bill              → admin created a new bill     (receivers: users)
  ///   meeting           → meeting scheduled            (receivers: users)
  ///   complaint         → new complaint / reply        (receivers: admin or user)
  ///   payment           → payment reported/verified    (receivers: admin or user)
  ///   resident_request  → new signup request           (receivers: admin)
  ///   president_registered → president signed up       (receivers: super admin)
  ///   president_transfer   → presidency transferred    (receivers: old/new admin)
  void _handleTap(RemoteMessage message) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      debugPrint('[FCM] _handleTap: navigator not ready yet.');
      return;
    }

    final type = message.data['type'] as String?;
    debugPrint('[FCM] Notification tapped — type: $type | data: ${message.data}');

    // Navigate to role-correct dashboard. The DashboardRouter will show the
    // relevant tab/screen. Deep-link to specific tabs can be added by passing
    // route arguments once per-role tab controllers are promoted to globals.
    navigator.pushNamedAndRemoveUntil('/dashboard', (route) => false);
  }
}
