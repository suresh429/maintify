import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../core/theme/role_theme.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _currentUser != null;
  UserRole? get role => _currentUser?.role;

  // Mock credentials
  static const Map<String, String> _credentials = {
    'superadmin@test.com': '123456',
    'admin@test.com': '123456',
    'user@test.com': '123456',
  };

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 1200));

    final trimmedEmail = email.trim().toLowerCase();
    final storedPassword = _credentials[trimmedEmail];

    if (storedPassword == null) {
      _error = 'No account found with this email.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    if (storedPassword != password) {
      _error = 'Incorrect password. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    final user = MockUsers.findByEmail(trimmedEmail);
    if (user == null) {
      _error = 'User data not found.';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    _currentUser = user;
    _isLoading = false;
    notifyListeners();
    return true;
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
