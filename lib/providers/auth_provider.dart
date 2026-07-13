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
      // ── Persist login state across restarts ───────────────────────────────
      final box = Hive.box<String>('session');
      box.put('isLoggedIn', 'true');
      box.put('role', _currentUser!.role.name);

      // ── Session: register this login as the active session ────────────────
      final sessionId = DateTime.now().millisecondsSinceEpoch.toString();
      _localSessionId = sessionId;
      box.put('session_${_currentUser!.id}', sessionId);
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
    final box = Hive.box<String>('session');
    box.delete('isLoggedIn');
    box.delete('role');
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
    final box = Hive.box<String>('session');
    if (_currentUser != null) {
      box.delete('session_${_currentUser!.id}');
    }
    box.delete('isLoggedIn');
    box.delete('role');
    _localSessionId = null;
    _sessionExpired = false;
    await _auth.signOut();
    _currentUser = null;
    _error = null;
    notifyListeners();
  }

  // ── Restore session after app restart ─────────────────────────────────────

  /// Called from SplashScreen. Checks if a previous login was persisted in
  /// Hive and, if so, re-hydrates [_currentUser] from Firestore using the
  /// Firebase Auth token that Firebase keeps alive between restarts.
  Future<void> tryRestoreSession() async {
    final box = Hive.box<String>('session');
    if (box.get('isLoggedIn') != 'true') return;

    final uid = _auth.currentUid; // Firebase Auth persists this across restarts
    if (uid == null) {
      // Auth token expired or was revoked — clear stale flag
      box.delete('isLoggedIn');
      box.delete('role');
      return;
    }

    try {
      final user = await _fs.getUser(uid);
      if (user == null) {
        box.delete('isLoggedIn');
        box.delete('role');
        return;
      }
      _currentUser = user;
      // Restore the active-session listener so single-device enforcement works
      _localSessionId = box.get('session_$uid');
      _startSessionListener(uid);
      // Re-init FCM so the token is refreshed and printed on every app start
      FcmService().init(uid).catchError((e) {
        debugPrint('[FCM] init error on restore for $uid: $e');
      });
      notifyListeners();
    } catch (e) {
      debugPrint('[AUTH] tryRestoreSession failed: $e');
      // Network error — clear persisted state and fall back to login
      box.delete('isLoggedIn');
      box.delete('role');
    }
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
