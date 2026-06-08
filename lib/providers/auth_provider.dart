import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../core/theme/role_theme.dart';
import '../core/utils/app_utils.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _currentUser != null;
  UserRole? get role => _currentUser?.role;
  bool get isFirstLogin => _currentUser?.isFirstLogin ?? false;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 1200));

    final trimmedEmail = email.trim().toLowerCase();
    final user = MockUsers.findByEmail(trimmedEmail);

    if (user == null) {
      _error = 'No account found with this email.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    if (user.password != password) {
      _error = 'Incorrect password. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    _currentUser = user;
    _isLoading = false;
    notifyListeners();
    return true;
  }

  /// Changes the current user's password. Returns true on success.
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_currentUser == null) return false;
    if (_currentUser!.password != currentPassword) {
      _error = 'Current password is incorrect.';
      notifyListeners();
      return false;
    }
    MockUsers.updatePassword(_currentUser!.id, newPassword);
    _currentUser = _currentUser!.copyWith(password: newPassword, isFirstLogin: false);
    _error = null;
    notifyListeners();
    return true;
  }

  /// Generates a new password for the given email (forgot password flow).
  /// Returns the new password string if the user exists, null otherwise.
  String? generateForgotPassword(String email) {
    final user = MockUsers.findByEmail(email.trim().toLowerCase());
    if (user == null) return null;
    final newPass = user.role == UserRole.admin
        ? AppUtils.generateAdminPassword(user.name)
        : AppUtils.generateUserPassword(user.name, user.unit);
    MockUsers.updatePassword(user.id, newPass);
    return newPass;
  }

  void logout() {
    _currentUser = null;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
