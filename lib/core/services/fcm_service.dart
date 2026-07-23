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
/// - `init()` is safe to call multiple times (re-login). `_initialized` guards
///   one-time listener registration.
/// - `clearToken(userId)` removes the FCM token from Firestore on logout so
///   stale tokens never receive pushes for signed-out users.
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

  static const _channelId   = 'maintify_notifications';
  static const _channelName = 'Maintify Notifications';

  // ── Public API ────────────────────────────────────────────────────────────

  /// Call once after every successful login.
  Future<void> init(String userId) async {
    _activeUserId = userId;
    debugPrint('[FCM] init() for $userId (initialized=$_initialized)');

    await _requestPermission();
    await _saveToken(userId);

    if (_initialized) return;
    _initialized = true;

    await _initLocalNotifications();

    // Token rotation — keep Firestore up to date
    _messaging.onTokenRefresh.listen((newToken) {
      final uid = _activeUserId;
      if (uid == null) return;
      debugPrint('[FCM] Token refreshed for $uid');
      _fs.updateUser(uid, {
        'fcmToken':         newToken,
        'lastTokenUpdated': DateTime.now().toIso8601String(),
      }).catchError((e) => debugPrint('[FCM] Token refresh save error: $e'));
    });

    // iOS: show system banner while app is in foreground
    if (Platform.isIOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // Foreground messages — show local notification on Android
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('[FCM] Foreground — ${message.notification?.title} | type: ${message.data["type"]}');
      if (Platform.isAndroid) _showLocalNotification(message);
    });

    // Background tap (app in background, not terminated)
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

  /// Call on logout — removes FCM token from Firestore so this device
  /// no longer receives notifications for the signed-out user.
  Future<void> clearToken(String userId) async {
    try {
      await _fs.updateUser(userId, {
        'fcmToken':            null,
        'notificationEnabled': false,
        'lastTokenUpdated':    DateTime.now().toIso8601String(),
      });
      debugPrint('[FCM] Token cleared for $userId');
    } catch (e) {
      debugPrint('[FCM] clearToken error: $e');
    }
    _activeUserId = null;
  }

  /// Returns the current FCM token (full string). Use in FcmDebugScreen.
  Future<String?> getToken() => _messaging.getToken();

  // ── Local notifications (Android foreground) ──────────────────────────────

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit     = DarwinInitializationSettings();
    const settings    = InitializationSettings(android: androidInit, iOS: iosInit);

    await _localNotif.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('[FCM] Local tap: payload=${details.payload}');
        _navigateFromPayload(details.payload);
      },
    );

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
            enableVibration: true,
          ),
        );

    debugPrint('[FCM] Local notifications initialised (channel: $_channelId)');
  }

  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    // Encode type + referenceId + referenceType as pipe-delimited payload
    final type          = message.data['type'] ?? '';
    final referenceId   = message.data['referenceId'] ?? '';
    final referenceType = message.data['referenceType'] ?? '';
    final payload       = '$type|$referenceId|$referenceType';

    _localNotif.show(
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
          enableVibration: true,
          visibility: NotificationVisibility.public,
        ),
      ),
      payload: payload,
    );
  }

  // ── Permission ────────────────────────────────────────────────────────────

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

    final uid = _activeUserId;
    if (uid != null) {
      _fs.updateUser(uid, {'notificationEnabled': granted})
          .catchError((e) => debugPrint('[FCM] notificationEnabled save error: $e'));
    }
  }

  // ── Token ─────────────────────────────────────────────────────────────────

  Future<void> _saveToken(String userId) async {
    debugPrint('[FCM] _saveToken for $userId');
    try {
      if (Platform.isIOS) {
        final apns = await _messaging.getAPNSToken();
        if (apns == null) {
          debugPrint('[FCM] APNS token not ready — skipping');
          return;
        }
      }

      final token = await _messaging.getToken().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('[FCM] getToken() timed out');
          return null;
        },
      );

      if (token == null) {
        debugPrint('[FCM] getToken() returned null');
        return;
      }

      // ignore: avoid_print
      print('╔══════════════════════════════════════════╗');
      // ignore: avoid_print
      print('║  FCM TOKEN (user: $userId)');
      // ignore: avoid_print
      print('║  $token');
      // ignore: avoid_print
      print('╚══════════════════════════════════════════╝');

      await _fs.updateUser(userId, {
        'fcmToken':            token,
        'notificationEnabled': true,
        'lastTokenUpdated':    DateTime.now().toIso8601String(),
        'platform':            Platform.isAndroid ? 'android' : 'ios',
      });
      debugPrint('[FCM] Token saved ✓');
    } catch (e) {
      debugPrint('[FCM] _saveToken error: $e');
    }
  }

  // ── Tap navigation ────────────────────────────────────────────────────────

  void _handleTap(RemoteMessage message) {
    final type          = message.data['type'] as String?;
    final referenceId   = message.data['referenceId'] as String?;
    final referenceType = message.data['referenceType'] as String?;
    final payload       = '${type ?? ''}|${referenceId ?? ''}|${referenceType ?? ''}';

    debugPrint('[FCM] Tapped — type: $type | referenceId: $referenceId');
    _navigateFromPayload(payload);
  }

  /// Parses a pipe-delimited payload and navigates to the correct screen.
  /// Payload format: "type|referenceId|referenceType"
  ///
  /// Navigates to /dashboard with a Map argument so DashboardRouter can
  /// deep-link to the correct tab or push the correct detail screen.
  void _navigateFromPayload(String? payload) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      debugPrint('[FCM] Navigator not ready — retrying in 500ms');
      Future.delayed(
        const Duration(milliseconds: 500),
        () => _navigateFromPayload(payload),
      );
      return;
    }

    final parts         = (payload ?? '').split('|');
    final type          = parts.isNotEmpty ? parts[0] : '';
    final referenceId   = parts.length > 1 ? parts[1] : '';
    final referenceType = parts.length > 2 ? parts[2] : '';

    debugPrint('[FCM] Navigate — type: $type | refId: $referenceId');

    navigator.pushNamedAndRemoveUntil(
      '/dashboard',
      (route) => false,
      arguments: {
        'notificationType': type,
        'referenceId':      referenceId,
        'referenceType':    referenceType,
      },
    );
  }
}
