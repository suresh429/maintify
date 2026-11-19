import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Delivers FCM push notifications via the Maintify Render notification server.
///
/// Responsibilities:
///   - Obtain a fresh Firebase Auth ID token for the currently logged-in user.
///   - POST to https://maintify-notification-server.onrender.com/send-notification
///   - Log the HTTP response.
///   - NEVER throw — push failure must never block complaint creation or reply.
///
/// The Render server resolves recipientUids → users/{uid}.fcmToken using
/// Firebase Admin SDK. Flutter never sends FCM registration tokens to Render.
///
/// Usage:
///   await NotificationPushService.instance.sendPush(
///     recipientUids: ['uid1', 'uid2'],
///     title: 'New Complaint',
///     body: 'A complaint was reported in your apartment.',
///     type: NotificationType.complaint,
///     referenceId: complaintId,
///   );
class NotificationPushService {
  NotificationPushService._();
  static final NotificationPushService instance = NotificationPushService._();

  static const _endpoint =
      'https://maintify-notification-server.onrender.com/send-notification';
  static const _broadcastEndpoint =
      'https://maintify-notification-server.onrender.com/send-update-notification';

  // Render Free may take up to 30 s to wake from sleep on first request.
  static const _timeout = Duration(seconds: 30);

  /// Sends an FCM push notification to one or more recipient UIDs.
  ///
  /// Safe to fire-and-forget — this method never throws.
  /// If the push fails, the Firestore in-app notification is already saved.
  Future<void> sendPush({
    required List<String> recipientUids,
    required String title,
    required String body,
    required String type,
    String referenceId = '',
    String referenceType = '',
  }) async {
    if (recipientUids.isEmpty) {
      debugPrint('[FCM-PUSH] No recipients — skipping push');
      return;
    }

    try {
      // Obtain a fresh Firebase Auth ID token.
      // NEVER send FCM registration tokens to the Render API.
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('[FCM-PUSH] No authenticated user — skipping push');
        return;
      }

      final idToken = await user.getIdToken();
      if (idToken == null) {
        debugPrint('[FCM-PUSH] Could not obtain Auth ID token — skipping push');
        return;
      }

      debugPrint('[FCM-PUSH] Sending push');
      debugPrint('[FCM-PUSH] recipientUids: ${recipientUids.length}');
      debugPrint('[FCM-PUSH] type: $type');
      debugPrint('[FCM-PUSH] referenceId: $referenceId');
      debugPrint('[FCM-PUSH] referenceType: $referenceType');
      debugPrint('[FCM-PUSH] endpoint: $_endpoint');

      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              // Auth ID token — never log it
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({
              'recipientUids': recipientUids,
              'title': title,
              'body': body,
              'type': type,
              'referenceId': referenceId,
              'referenceType': referenceType,
            }),
          )
          .timeout(_timeout);

      debugPrint('[FCM-PUSH] HTTP status: ${response.statusCode}');

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final successCount = data['successCount'] ?? 0;
          final failureCount = data['failureCount'] ?? 0;
          debugPrint(
              '[FCM-PUSH] response: successCount=$successCount failureCount=$failureCount');
          if (successCount > 0) {
            debugPrint('[FCM-PUSH] Push sent successfully');
          } else {
            debugPrint(
                '[FCM-PUSH] Server accepted request but 0 devices received push');
          }
        } catch (_) {
          debugPrint('[FCM-PUSH] response: ${response.statusCode}');
        }
      } else {
        // Do not log the full response body — it may contain diagnostic info
        // with partial token data.
        debugPrint('[FCM-PUSH] Push failed: HTTP ${response.statusCode}');
      }
    } on TimeoutException {
      debugPrint(
          '[FCM-PUSH] Push timed out — Render may be waking up. '
          'Firestore notification is preserved.');
    } catch (e) {
      debugPrint('[FCM-PUSH] Push failed: ${e.runtimeType}');
    }
  }

  /// Broadcasts an update notification to ALL presidents and residents.
  /// Returns `(success, sentCount, error)` — always returns, never throws.
  Future<({bool success, int sentCount, String? error})> sendUpdateNotification({
    required String title,
    required String body,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return (success: false, sentCount: 0, error: 'Not authenticated');

      final idToken = await user.getIdToken();
      if (idToken == null) return (success: false, sentCount: 0, error: 'Could not get auth token');

      debugPrint('[FCM-BROADCAST] Sending update notification to all users');

      final response = await http
          .post(
            Uri.parse(_broadcastEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: jsonEncode({'title': title, 'body': body}),
          )
          .timeout(const Duration(seconds: 60));

      debugPrint('[FCM-BROADCAST] HTTP status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final sent = (data['successCount'] as int?) ?? 0;
        debugPrint('[FCM-BROADCAST] Sent to $sent devices');
        return (success: true, sentCount: sent, error: null);
      }

      final data = _parseJson(response.body);
      return (
        success: false,
        sentCount: 0,
        error: data['error'] as String? ?? 'Failed to send notification',
      );
    } on TimeoutException {
      return (success: false, sentCount: 0, error: 'Request timed out. Please try again.');
    } catch (e) {
      return (success: false, sentCount: 0, error: 'Something went wrong. Please try again.');
    }
  }

  static Map<String, dynamic> _parseJson(String body) {
    try { return jsonDecode(body) as Map<String, dynamic>; } catch (_) { return {}; }
  }
}
