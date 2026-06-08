import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../core/theme/role_theme.dart';
import '../core/utils/app_utils.dart';

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

  /// All members of [aptId] (admin + residents, not super admin).
  List<UserModel> membersForApartment(String aptId) => _users
      .where((u) => u.apartmentId == aptId && u.role != UserRole.superAdmin)
      .toList();

  int memberCountForApartment(String aptId) =>
      membersForApartment(aptId).length;

  bool canAddMember(String aptId, int maxFlats) =>
      memberCountForApartment(aptId) < maxFlats;

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

  /// Returns users in [aptId] who are NOT already a president of any apartment.
  List<UserModel> eligibleForPresident(String aptId) {
    final presidentIds =
        _users.where((u) => u.role == UserRole.admin).map((u) => u.id).toSet();
    return _users
        .where((u) => u.apartmentId == aptId && !presidentIds.contains(u.id))
        .toList();
  }

  bool isAlreadyPresident(String userId) =>
      _users.any((u) => u.id == userId && u.role == UserRole.admin);

  /// Promotes [newPresidentId] to admin and demotes [oldPresidentId] (if any) to user.
  Future<void> updatePresidentRoles(
      String? oldPresidentId, String newPresidentId) async {
    final newIdx = _users.indexWhere((u) => u.id == newPresidentId);
    if (newIdx != -1) {
      _users[newIdx] = _users[newIdx].copyWith(role: UserRole.admin);
      MockUsers.updateRole(newPresidentId, UserRole.admin);
    }

    if (oldPresidentId != null && oldPresidentId != newPresidentId) {
      final oldIdx = _users.indexWhere((u) => u.id == oldPresidentId);
      if (oldIdx != -1) {
        _users[oldIdx] = _users[oldIdx].copyWith(role: UserRole.user);
        MockUsers.updateRole(oldPresidentId, UserRole.user);
      }
    }

    notifyListeners();
  }

  Future<void> toggleUserStatus(String userId) async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 400));
    _isLoading = false;
    notifyListeners();
  }

  /// Creates an admin user for a newly created apartment.
  /// Auto-generates a password. Returns `({id, password})`. Throws if email already registered.
  ({String id, String password}) createAdmin({
    required String name,
    required String email,
    required String aptName,
    required String aptId,
    required String unit,
  }) {
    if (_users.any((u) =>
        u.email.isNotEmpty &&
        u.email.trim().toLowerCase() == email.trim().toLowerCase())) {
      throw Exception('Email is already registered');
    }

    final words = name.trim().split(RegExp(r'\s+'));
    final initials = words
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    final password = AppUtils.generateAdminPassword(aptName);
    final id = 'ua_${DateTime.now().millisecondsSinceEpoch}';
    final newAdmin = UserModel(
      id: id,
      name: name.trim(),
      email: email.trim().toLowerCase(),
      password: password,
      phone: '',
      role: UserRole.admin,
      apartmentId: aptId,
      unit: unit.trim(),
      avatarInitials: initials.isEmpty ? name.trim()[0].toUpperCase() : initials,
      joinedAt: DateTime.now(),
      isFirstLogin: true,
    );

    _users.add(newAdmin);
    MockUsers.all.add(newAdmin);
    notifyListeners();
    return (id: id, password: password);
  }

  /// Adds a new resident to [aptId].
  /// Auto-generates a password. Returns the generated password. Validates capacity, flat duplicate, and email duplicate.
  String addMember({
    required String flatNumber,
    required String name,
    required String email,
    required String aptId,
    required int maxFlats,
  }) {
    final inApt = membersForApartment(aptId);

    if (inApt.length >= maxFlats) {
      throw Exception('All $maxFlats flats are occupied. Cannot add more members.');
    }

    if (inApt.any((u) => u.unit.trim() == flatNumber.trim())) {
      throw Exception('Flat $flatNumber already has a member');
    }

    final trimmedEmail = email.trim().toLowerCase();
    if (trimmedEmail.isNotEmpty &&
        _users.any((u) =>
            u.email.isNotEmpty &&
            u.email.trim().toLowerCase() == trimmedEmail)) {
      throw Exception('Email is already registered');
    }

    final words = name.trim().split(RegExp(r'\s+'));
    final initials = words
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    final password = AppUtils.generateUserPassword(name, flatNumber);
    final newUser = UserModel(
      id: 'um_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      email: trimmedEmail,
      password: password,
      phone: '',
      role: UserRole.user,
      apartmentId: aptId,
      unit: flatNumber.trim(),
      avatarInitials: initials.isEmpty ? name.trim()[0].toUpperCase() : initials,
      joinedAt: DateTime.now(),
      isFirstLogin: true,
    );

    _users.add(newUser);
    MockUsers.all.add(newUser);
    notifyListeners();
    return password;
  }
}
