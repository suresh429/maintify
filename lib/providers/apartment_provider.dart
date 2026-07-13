import 'dart:async';
import 'package:flutter/material.dart';
import '../models/apartment_model.dart';
import '../models/user_model.dart';
import '../core/theme/role_theme.dart';
import '../core/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_provider.dart';

class ApartmentProvider extends ChangeNotifier {
  final FirestoreService _fs = FirestoreService();

  List<ApartmentModel> _apartments = []; // start empty — server is source of truth
  StreamSubscription<List<ApartmentModel>>? _sub;
  bool _isInitialLoading = false;
  bool _isLoading = false;

  List<ApartmentModel> get apartments => _apartments;
  bool get isInitialLoading => _isInitialLoading;
  bool get isLoading => _isLoading;

  // ── Start listening ───────────────────────────────────────────────────────

  void startListening() {
    _sub?.cancel();
    // Hard reset: clear before any server data arrives.
    _apartments = [];
    _isInitialLoading = true;
    MockApartments.replaceAll([]);
    notifyListeners();

    _sub = _fs.streamApartments().listen((list) {
      debugPrint('[REALTIME] Apartments updated: ${list.length} doc(s)');
      _apartments = list;
      _isInitialLoading = false;
      MockApartments.replaceAll(list); // keep statics in sync
      notifyListeners();
    }, onError: (e) {
      debugPrint('[REALTIME] Apartments stream ERROR: $e');
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
    NotificationProvider? notifProvider,
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

    // In-app notifications (Fire-and-forget; FCM push is handled by Cloud Function)
    if (notifProvider != null) {
      notifProvider
          .addAndPersistNotification(
            title: 'You Are Now the Apartment President',
            body: 'You have been assigned as president of the apartment.',
            type: 'president_transfer',
            targetRole: UserRole.admin,
            targetUserIds: [newPresidentId],
          )
          .catchError((e) => debugPrint('[NOTIF] president_transfer new: $e'));

      if (oldPresidentId != null && oldPresidentId != newPresidentId) {
        notifProvider
            .addAndPersistNotification(
              title: 'President Role Transferred',
              body: 'Your president role has been transferred to $newPresidentName.',
              type: 'president_transfer',
              targetRole: UserRole.user,
              targetUserIds: [oldPresidentId],
            )
            .catchError((e) => debugPrint('[NOTIF] president_transfer old: $e'));
      }
    }
  }

  Future<void> createApartment({
    String? id,
    required String name,
    required int totalFlats,
    String? presidentName,
    String? presidentEmail,
    String? presidentPhone,
    // New canonical field name
    String? code,
    // Legacy / UI-facing aliases (accepted but not written to Firestore)
    @Deprecated('Field removed from schema') String? address,
    @Deprecated('Field removed from schema') String? city,
    @Deprecated('Field removed from schema') List<String> amenities = const [],
    @Deprecated('Use code instead') String? apartmentCode,
  }) async {
    _isLoading = true;
    notifyListeners();

    final now = DateTime.now();
    final docId = id ?? 'apt_${now.millisecondsSinceEpoch}';
    // Prefer explicit `code`, fall back to legacy `apartmentCode`
    final resolvedCode = code ?? apartmentCode ?? '';

    final data = {
      'name': name,
      'code': resolvedCode,
      'totalFlats': totalFlats,
      'presidentId': null,
      'presidentName': presidentName,
      'presidentEmail': presidentEmail,
      'presidentPhone': presidentPhone,
      'status': 'waiting_for_president',
      'occupiedFlats': 0,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    };

    await _fs.createApartment(docId, data);

    _isLoading = false;
    notifyListeners();
  }
}
