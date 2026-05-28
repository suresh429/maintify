import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../core/theme/role_theme.dart';

class UserProvider extends ChangeNotifier {
  final List<UserModel> _users = List.from(MockUsers.all);
  bool _isLoading = false;

  List<UserModel> get users => _users;
  bool get isLoading => _isLoading;

  List<UserModel> get residents =>
      _users.where((u) => u.role == UserRole.user).toList();

  List<UserModel> get admins =>
      _users.where((u) => u.role == UserRole.admin).toList();

  List<UserModel> residentsForApartment(String aptId) => _users
      .where((u) => u.role == UserRole.user && u.apartmentId == aptId)
      .toList();

  List<UserModel> searchUsers(String query, {String? aptId}) {
    var list = aptId != null ? residentsForApartment(aptId) : residents;
    if (query.isEmpty) return list;
    final q = query.toLowerCase();
    return list
        .where((u) =>
            u.name.toLowerCase().contains(q) ||
            u.unit.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q))
        .toList();
  }

  Future<void> toggleUserStatus(String userId) async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 400));
    _isLoading = false;
    notifyListeners();
  }
}
