import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../core/theme/role_theme.dart';
import '../core/services/firebase_auth_service.dart';
import '../core/services/fcm_service.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuthService _auth = FirebaseAuthService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _currentUser != null;
  UserRole? get role => _currentUser?.role;
  bool get isFirstLogin => _currentUser?.isFirstLogin ?? false;

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

    // Initialise FCM in background — don't await to keep login fast.
    // Errors are caught and logged; a failure here must never block login.
    if (_currentUser != null) {
      FcmService().init(_currentUser!.id).catchError((e) {
        debugPrint('[FCM] init error for ${_currentUser?.id}: $e');
      });
    }

    return true;
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
    await _auth.signOut();
    _currentUser = null;
    _error = null;
    notifyListeners();
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
