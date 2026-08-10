import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../core/theme/role_theme.dart';
import '../core/services/firestore_service.dart';

class UserProvider extends ChangeNotifier {
  final FirestoreService _fs = FirestoreService();

  List<UserModel> _users = []; // start empty — server is source of truth
  StreamSubscription<List<UserModel>>? _sub;
  bool _isInitialLoading = false;
  bool _isLoading = false;

  List<UserModel> get users => _users;
  bool get isInitialLoading => _isInitialLoading;
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
    // Hard reset: clear before any server data arrives.
    _users = [];
    _isInitialLoading = true;
    MockUsers.replaceAll([]);
    notifyListeners();

    _sub = _fs.streamUsers().listen((list) {
      debugPrint('[REALTIME] Users updated: ${list.length} doc(s)');
      _users = list;
      _isInitialLoading = false;
      MockUsers.replaceAll(list); // keep statics in sync for DashboardProvider
      notifyListeners();
    }, onError: (e) {
      debugPrint('[REALTIME] Users stream ERROR: $e');
      _isInitialLoading = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  List<UserModel> get residents =>
      _users.where((u) => u.role == UserRole.resident).toList();

  List<UserModel> get admins =>
      _users.where((u) => u.role == UserRole.president).toList();

  List<UserModel> residentsForApartment(String aptId) => _users
      .where((u) => u.role == UserRole.resident && u.apartmentId == aptId)
      .toList();

  List<UserModel> membersForApartment(String aptId) => _users
      .where((u) => u.apartmentId == aptId && u.role != UserRole.admin)
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
        _users.where((u) => u.role == UserRole.president).map((u) => u.id).toSet();
    return _users
        .where((u) => u.apartmentId == aptId && !presidentIds.contains(u.id))
        .toList();
  }

  bool isAlreadyPresident(String userId) =>
      _users.any((u) => u.id == userId && u.role == UserRole.president);

  // ── Mutations ─────────────────────────────────────────────────────────────

  Future<void> updatePresidentRoles(
      String? oldPresidentId, String newPresidentId) async {
    await _fs.updateUser(newPresidentId, {'role': UserRole.president.name});
    MockUsers.updateRole(newPresidentId, UserRole.president);

    if (oldPresidentId != null && oldPresidentId != newPresidentId) {
      await _fs.updateUser(oldPresidentId, {'role': UserRole.resident.name});
      MockUsers.updateRole(oldPresidentId, UserRole.resident);
    }
    notifyListeners();
  }

  Future<void> editUser(
      String userId, {required String name, required String phone}) async {
    final words = name.trim().split(RegExp(r'\s+'));
    final initials = words
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    await _fs.updateUser(userId, {
      'name': name.trim(),
      'phone': phone.trim(),
      'avatarInitials':
          initials.isEmpty ? name[0].toUpperCase() : initials,
    });
    notifyListeners();
  }

  /// Removes a user from their apartment:
  /// clears flat, clears apartmentId + unit, deactivates account.
  /// If the user is president, also clears the apartment's presidentId.
  Future<void> removeUser(
    String userId, {
    required String aptId,
    required bool isPresident,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final user = findById(userId);
      if (user != null && user.unit.isNotEmpty) {
        final flat = await _fs.getFlatByNumber(aptId, user.unit);
        if (flat != null) {
          await _fs.clearFlatResident(flat.id);
        }
      }
      await _fs.updateUser(userId, {
        'apartmentId': null,
        'unit': '',
        'isActive': false,
        if (isPresident) 'role': 'resident',
      });
      if (isPresident) {
        await _fs.updateApartment(aptId, {
          'presidentId': null,
          'presidentName': null,
        });
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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

}
