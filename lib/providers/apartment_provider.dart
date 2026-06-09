import 'dart:async';
import 'package:flutter/material.dart';
import '../models/apartment_model.dart';
import '../models/user_model.dart';
import '../core/theme/role_theme.dart';
import '../core/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ApartmentProvider extends ChangeNotifier {
  final FirestoreService _fs = FirestoreService();

  List<ApartmentModel> _apartments = List.from(MockApartments.all);
  StreamSubscription<List<ApartmentModel>>? _sub;
  bool _isLoading = false;

  List<ApartmentModel> get apartments => _apartments;
  bool get isLoading => _isLoading;

  // ── Start listening ───────────────────────────────────────────────────────

  void startListening() {
    _sub?.cancel();
    _sub = _fs.streamApartments().listen((list) {
      _apartments = list;
      MockApartments.replaceAll(list); // keep statics in sync
      notifyListeners();
      // Migrate any apartments still holding a pending_* presidentId
      for (final apt in list) {
        if (apt.presidentId != null && apt.presidentId!.startsWith('pending_')) {
          _migratePendingPresident(apt);
        }
      }
    }, onError: (_) {});
  }

  /// Finds the real admin user for [apt] and updates the apartment document.
  Future<void> _migratePendingPresident(ApartmentModel apt) async {
    final realAdmin = await _fs.findAdminForApartment(apt.id);
    if (realAdmin == null) {
      // No real admin yet — just clear the invalid pending ID
      await _fs.updateApartment(apt.id, {
        'presidentId': null,
        'presidentName': apt.presidentName,
      });
    } else {
      await _fs.updateApartment(apt.id, {
        'presidentId': realAdmin.id,
        'presidentName': realAdmin.name,
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  ApartmentModel? findById(String id) {
    try {
      return _apartments.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  String presidentName(ApartmentModel apt) {
    if (!apt.hasPresident) return 'Unassigned';
    return apt.presidentName ?? MockUsers.findById(apt.presidentId!)?.name ?? 'Unassigned';
  }

  List<ApartmentModel> get withPresident =>
      _apartments.where((a) => a.hasPresident).toList();

  List<ApartmentModel> get withoutPresident =>
      _apartments.where((a) => !a.hasPresident).toList();

  String? currentPresidentId(String aptId) => findById(aptId)?.presidentId;

  bool isPresidentElsewhere(String userId, {String? excludingAptId}) =>
      _apartments.any((a) =>
          a.presidentId == userId &&
          (excludingAptId == null || a.id != excludingAptId));

  // ── Mutations ─────────────────────────────────────────────────────────────

  Future<void> assignPresident(
    String aptId,
    String newPresidentId,
    String newPresidentName, {
    String? oldPresidentId,
  }) async {
    if (isPresidentElsewhere(newPresidentId, excludingAptId: aptId)) {
      throw StateError('User is already president of another apartment');
    }
    _isLoading = true;
    notifyListeners();

    await _fs.assignPresidentBatch(
      aptId: aptId,
      newPresidentId: newPresidentId,
      newPresidentName: newPresidentName,
      newPresidentApartmentId: aptId,
      oldPresidentId: oldPresidentId,
    );
    MockApartments.assignPresident(aptId, newPresidentId, newPresidentName);
    if (oldPresidentId != null && oldPresidentId != newPresidentId) {
      MockUsers.updateRole(oldPresidentId, UserRole.user);
    }
    MockUsers.updateRole(newPresidentId, UserRole.admin);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> createApartment({
    String? id,
    required String name,
    required String address,
    required String city,
    required int totalFlats,
    List<String> amenities = const [],
    // presidentId is intentionally NOT accepted here — a pending_users record
    // never has a real UID. presidentId is set atomically via assignPresidentBatch
    // after the admin's first login creates their real users/ document.
    String? presidentName,
  }) async {
    _isLoading = true;
    notifyListeners();

    final docId = id ?? 'apt_${DateTime.now().millisecondsSinceEpoch}';
    final data = {
      'name': name,
      'address': address,
      'city': city,
      'totalFlats': totalFlats,
      'presidentId': null,
      'presidentName': presidentName,
      'amenities': amenities,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    };

    await _fs.createApartment(docId, data);

    _isLoading = false;
    notifyListeners();
  }
}
