import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/user_model.dart';
import '../core/theme/role_theme.dart';
import '../core/services/firebase_auth_service.dart';
import '../core/services/firestore_service.dart';
import '../core/services/fcm_service.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuthService _auth = FirebaseAuthService();
  final FirestoreService _fs = FirestoreService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;

  // ── Session management ────────────────────────────────────────────────────
  // Tracks whether this device's session is still the active one.
  // On login a unique sessionId is written to Firestore and stored locally.
  // A real-time listener watches for changes; if another device logs in it
  // overwrites the Firestore sessionId → this device is force-logged out.
  String? _localSessionId;
  StreamSubscription<String?>? _sessionSub;
  bool _sessionExpired = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _currentUser != null;
  UserRole? get role => _currentUser?.role;
  bool get isFirstLogin => _currentUser?.isFirstLogin ?? false;
  /// True when this session was ended by a login from another device.
  /// LoginScreen reads this to show a one-time banner, then clears it.
  bool get sessionExpired => _sessionExpired;

  void clearSessionExpired() {
    _sessionExpired = false;
  }

  // ── Login ─────────────────────────────────────────────────────────────────

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _auth.signIn(email, password);

    _isLoading = false;
    if (result.error != null) {
      _error = result.error;
      notifyListeners();
      return false;
    }

    _currentUser = result.user;
    notifyListeners();

    if (_currentUser != null) {
      // ── Session: register this login as the active session ────────────────
      final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      _localSessionId = sessionId;
      Hive.box<String>('session').put('session_${_currentUser!.id}', sessionId);
      // Write to Firestore in background — don't block the UI.
      _fs.updateUser(_currentUser!.id, {'activeSessionId': sessionId})
          .catchError((e) => debugPrint('[SESSION] Write failed: $e'));
      _startSessionListener(_currentUser!.id);

      // ── FCM: initialise in background ─────────────────────────────────────
      FcmService().init(_currentUser!.id).catchError((e) {
        debugPrint('[FCM] init error for ${_currentUser?.id}: $e');
      });
    }

    return true;
  }

  void _startSessionListener(String userId) {
    _sessionSub?.cancel();
    _sessionSub = _fs.streamUserSessionId(userId).listen((remoteId) {
      // Ignore null (field not yet written) and initial echo of our own write.
      if (remoteId == null || _localSessionId == null) return;
      if (remoteId != _localSessionId) {
        _forceLogout();
      }
    }, onError: (e) {
      debugPrint('[SESSION] Listener error: $e');
    });
  }

  Future<void> _forceLogout() async {
    _sessionSub?.cancel();
    _sessionSub = null;
    _localSessionId = null;
    await _auth.signOut();
    _currentUser = null;
    _sessionExpired = true;
    notifyListeners();
  }

  // ── Change password ───────────────────────────────────────────────────────

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_currentUser == null) return false;
    _error = null;

    final result = await _auth.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );

    if (!result.ok) {
      _error = result.error ?? 'Current password is incorrect.';
      notifyListeners();
      return false;
    }

    _currentUser = _currentUser!.copyWith(isFirstLogin: false);
    notifyListeners();
    return true;
  }

  // ── Forgot password (sends a reset email) ────────────────────────────────

  /// Returns a message string to show the user.
  /// In production this sends a Firebase password-reset email.
  Future<String?> generateForgotPassword(String email) async {
    final sent = await _auth.sendPasswordResetEmail(email);
    if (!sent) return null;
    // Return a display string so the UI (which shows this in a dialog) works.
    return 'Reset link sent to $email';
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    _sessionSub?.cancel();
    _sessionSub = null;
    if (_currentUser != null) {
      Hive.box<String>('session').delete('session_${_currentUser!.id}');
    }
    _localSessionId = null;
    _sessionExpired = false;
    await _auth.signOut();
    _currentUser = null;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    super.dispose();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Called by UserProvider / ApartmentProvider when user data changes
  /// (e.g. role change after president transfer).
  void refreshUser(UserModel updated) {
    if (_currentUser?.id == updated.id) {
      _currentUser = updated;
      notifyListeners();
    }
  }
}
