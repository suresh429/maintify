import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'firestore_service.dart';

/// Handles Firebase Cloud Messaging — token retrieval, permission requests,
/// and foreground/background message callbacks.
class FcmService {
  static final FcmService _instance = FcmService._();
  factory FcmService() => _instance;
  FcmService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirestoreService _fs = FirestoreService();

  /// Call once after login. Requests permission (iOS) and saves token.
  Future<void> init(String userId) async {
    await _requestPermission();
    final token = await _messaging.getToken();
    if (token != null) {
      await _fs.updateUser(userId, {'fcmToken': token});
    }

    // Token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      _fs.updateUser(userId, {'fcmToken': newToken});
    });

    // Foreground message handler
    FirebaseMessaging.onMessage.listen(_handleForeground);
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (kDebugMode) {
      debugPrint('FCM permission: ${settings.authorizationStatus}');
    }
  }

  void _handleForeground(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint(
          'FCM foreground: ${message.notification?.title} — ${message.notification?.body}');
    }
    // In-app notification display is handled by the NotificationProvider
    // stream from Firestore — no additional action needed here.
  }

  /// Returns the current FCM token (for debug/testing).
  Future<String?> getToken() => _messaging.getToken();
}
