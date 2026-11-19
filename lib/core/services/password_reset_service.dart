import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Communicates with the Maintify Render notification server to implement
/// OTP-based password reset without redirecting the user to a browser.
///
/// Both methods are fire-and-recover: they never throw; all errors are
/// captured and returned as [({bool success, String? error})].
class PasswordResetService {
  static const _base = 'https://maintify-notification-server.onrender.com';
  static const _timeout = Duration(seconds: 60);

  // ── Send OTP ───────────────────────────────────────────────────────────────

  /// Sends a 6-digit OTP to [email].
  ///
  /// Returns `(success: true, error: null)` on success.
  /// Returns `(success: false, error: '...')` on failure — including
  /// a user-friendly message on 429 (rate limited).
  static Future<({bool success, String? error})> sendOtp(String email) async {
    debugPrint('[PASSWORD_RESET] Sending OTP request for: $email');
    try {
      final response = await http
          .post(
            Uri.parse('$_base/send-reset-otp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
          )
          .timeout(_timeout);

      debugPrint('[PASSWORD_RESET] sendOtp status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return (success: true, error: null);
      }

      if (response.statusCode == 429) {
        return (
          success: false,
          error: 'Please wait 60 seconds before requesting another OTP.',
        );
      }

      final body = _parseBody(response.body);
      final message = body['error'] as String? ?? 'Failed to send OTP. Please try again.';
      return (success: false, error: message);
    } on TimeoutException {
      debugPrint('[PASSWORD_RESET] sendOtp timed out');
      return (success: false, error: 'Request timed out. Please try again.');
    } catch (e) {
      debugPrint('[PASSWORD_RESET] sendOtp error: $e');
      return (success: false, error: 'Something went wrong. Please try again.');
    }
  }

  // ── Reset Password ─────────────────────────────────────────────────────────

  /// Verifies [otp] and sets [newPassword] for [email].
  ///
  /// Returns `(success: true, error: null)` on success.
  /// Returns `(success: false, error: '...')` on any failure.
  static Future<({bool success, String? error})> resetPassword(
    String email,
    String otp,
    String newPassword,
  ) async {
    debugPrint('[PASSWORD_RESET] Submitting OTP verification for: $email');
    try {
      final response = await http
          .post(
            Uri.parse('$_base/reset-password-otp'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'otp': otp,
              'newPassword': newPassword,
            }),
          )
          .timeout(_timeout);

      debugPrint('[PASSWORD_RESET] resetPassword status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return (success: true, error: null);
      }

      final body = _parseBody(response.body);
      final message = body['error'] as String? ?? 'Failed to reset password. Please try again.';
      return (success: false, error: message);
    } on TimeoutException {
      debugPrint('[PASSWORD_RESET] resetPassword timed out');
      return (success: false, error: 'Request timed out. Please try again.');
    } catch (e) {
      debugPrint('[PASSWORD_RESET] resetPassword error: $e');
      return (success: false, error: 'Something went wrong. Please try again.');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static Map<String, dynamic> _parseBody(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}
