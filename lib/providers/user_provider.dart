import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../core/theme/role_theme.dart';
import '../core/utils/app_utils.dart';
import '../core/services/firestore_service.dart';

class UserProvider extends ChangeNotifier {
  final FirestoreService _fs = FirestoreService();

  List<UserModel> _users = List.from(MockUsers.all);
  StreamSubscription<List<UserModel>>? _sub;
  bool _isLoading = false;

  List<UserModel> get users => _users;
  bool get isLoading => _isLoading;

  UserModel? findById(String id) {
    try {
      return _users.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── Start listening ───────────────────────────────────────────────────────

  void startListening() {
    _sub?.cancel();
    _sub = _fs.streamUsers().listen((list) {
      _users = list;
      MockUsers.replaceAll(list); // keep statics in sync for DashboardProvider
      notifyListeners();
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  List<UserModel> get residents =>
      _users.where((u) => u.role == UserRole.user).toList();

  List<UserModel> get admins =>
      _users.where((u) => u.role == UserRole.admin).toList();

  List<UserModel> residentsForApartment(String aptId) => _users
      .where((u) => u.role == UserRole.user && u.apartmentId == aptId)
      .toList();

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

  List<UserModel> eligibleForPresident(String aptId) {
    final presidentIds =
        _users.where((u) => u.role == UserRole.admin).map((u) => u.id).toSet();
    return _users
        .where((u) => u.apartmentId == aptId && !presidentIds.contains(u.id))
        .toList();
  }

  bool isAlreadyPresident(String userId) =>
      _users.any((u) => u.id == userId && u.role == UserRole.admin);

  // ── Mutations ─────────────────────────────────────────────────────────────

  Future<void> updatePresidentRoles(
      String? oldPresidentId, String newPresidentId) async {
    await _fs.updateUser(newPresidentId, {'role': UserRole.admin.name});
    MockUsers.updateRole(newPresidentId, UserRole.admin);

    if (oldPresidentId != null && oldPresidentId != newPresidentId) {
      await _fs.updateUser(oldPresidentId, {'role': UserRole.user.name});
      MockUsers.updateRole(oldPresidentId, UserRole.user);
    }
    notifyListeners();
  }

  Future<void> toggleUserStatus(String userId) async {
    _isLoading = true;
    notifyListeners();
    final idx = _users.indexWhere((u) => u.id == userId);
    if (idx != -1) {
      final newStatus = !_users[idx].isActive;
      await _fs.updateUser(userId, {'isActive': newStatus});
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Creates an admin user record in Firestore `pending_users`.
  /// The Firebase Auth account is created on the user's first sign-in.
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
    final id = 'pending_${DateTime.now().millisecondsSinceEpoch}';

    _fs.createPendingUser({
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'tempPassword': password,
      'phone': '',
      'role': UserRole.admin.name,
      'apartmentId': aptId,
      'unit': unit.trim(),
      'avatarInitials':
          initials.isEmpty ? name.trim()[0].toUpperCase() : initials,
      'isActive': true,
      'isFirstLogin': true,
      'joinedAt': Timestamp.fromDate(DateTime.now()),
    }).ignore();

    notifyListeners();
    return (id: id, password: password);
  }

  /// Adds a new resident via `pending_users`. Returns the generated password.
  String addMember({
    required String flatNumber,
    required String name,
    required String email,
    required String aptId,
    required int maxFlats,
  }) {
    final inApt = membersForApartment(aptId);

    if (inApt.length >= maxFlats) {
      throw Exception(
          'All $maxFlats flats are occupied. Cannot add more members.');
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

    _fs.createPendingUser({
      'name': name.trim(),
      'email': trimmedEmail,
      'tempPassword': password,
      'phone': '',
      'role': UserRole.user.name,
      'apartmentId': aptId,
      'unit': flatNumber.trim(),
      'avatarInitials':
          initials.isEmpty ? name.trim()[0].toUpperCase() : initials,
      'isActive': true,
      'isFirstLogin': true,
      'joinedAt': Timestamp.fromDate(DateTime.now()),
    }).ignore();

    notifyListeners();
    return password;
  }
}
