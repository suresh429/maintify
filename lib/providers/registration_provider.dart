import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/resident_request_model.dart';
import '../core/theme/role_theme.dart';
import '../core/services/firestore_service.dart';
import '../core/services/firebase_auth_service.dart';
import 'notification_provider.dart';

class RegistrationProvider extends ChangeNotifier {
  final FirestoreService _fs = FirestoreService();
  final FirebaseAuthService _authService = FirebaseAuthService();

  bool _isLoading = false;
  String? _error;
  List<ResidentRequestModel> _requests = [];
  StreamSubscription<List<ResidentRequestModel>>? _requestsSub;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<ResidentRequestModel> get requests => _requests;
  List<ResidentRequestModel> get pendingRequests =>
      _requests.where((r) => r.status == 'pending').toList();

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Stream management ─────────────────────────────────────────────────────

  /// Start listening to resident requests for an apartment (called by admin).
  void startListeningRequests(String aptId) {
    _requestsSub?.cancel();
    _requestsSub = _fs.streamResidentRequests(aptId).listen((list) {
      _requests = list;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _requestsSub?.cancel();
    super.dispose();
  }

  // ── President self-registration ───────────────────────────────────────────

  /// Looks up the apartment by code, validates email + status, then registers
  /// the president via [FirebaseAuthService.registerPresident].
  /// Returns (user, error). On success user is non-null.
  Future<({dynamic user, String? error})> registerPresident({
    required String email,
    required String password,
    required String apartmentCode,
    required String unit,
    required NotificationProvider notifProvider,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // 1. Lookup apartment by code
    final apt =
        await _fs.findApartmentByCode(apartmentCode.trim().toUpperCase());
    if (apt == null) {
      _error = 'Invalid Apartment Code. Please check and try again.';
      _isLoading = false;
      notifyListeners();
      return (user: null, error: _error);
    }

    // 2. Verify status
    if (apt.status == 'active') {
      _error = 'This apartment already has a registered president.';
      _isLoading = false;
      notifyListeners();
      return (user: null, error: _error);
    }
    if (apt.status == 'disabled') {
      _error = 'This apartment is currently disabled.';
      _isLoading = false;
      notifyListeners();
      return (user: null, error: _error);
    }

    // 3. Verify email matches the pre-registered president email
    final emailTrimmed = email.trim().toLowerCase();
    if (apt.presidentEmail?.toLowerCase() != emailTrimmed) {
      _error =
          'This email is not authorized for President registration for this apartment.';
      _isLoading = false;
      notifyListeners();
      return (user: null, error: _error);
    }

    // 4. Register via auth service
    final result = await _authService.registerPresident(
      email: emailTrimmed,
      password: password,
      apt: apt,
      unit: unit.trim(),
    );

    if (result.error != null) {
      _error = result.error;
      _isLoading = false;
      notifyListeners();
      return (user: null, error: _error);
    }

    // 5. Notify all super admins
    await notifProvider
        .addAndPersistNotification(
          title: 'New President Registered',
          body:
              '${apt.presidentName ?? 'A president'} has joined ${apt.name} as President.',
          type: 'president_registered',
          targetRole: UserRole.superAdmin,
        )
        .catchError(
            (e) => debugPrint('[NOTIF] president_registered error: $e'));

    _isLoading = false;
    notifyListeners();
    return (user: result.user, error: null);
  }

  // ── Resident self-registration ────────────────────────────────────────────

  /// Creates a Firebase Auth account, signs out immediately, then creates a
  /// resident_request doc awaiting admin approval.
  /// Returns null on success; returns an error string on failure.
  Future<String?> registerResident({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String apartmentCode,
    required String unit,
    required NotificationProvider notifProvider,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // 1. Lookup apartment
    final apt =
        await _fs.findApartmentByCode(apartmentCode.trim().toUpperCase());
    if (apt == null) {
      _error = 'Invalid Apartment Code. Please check and try again.';
      _isLoading = false;
      notifyListeners();
      return _error;
    }

    if (apt.status != 'active') {
      _error =
          'This apartment is not yet active. Please contact the apartment president.';
      _isLoading = false;
      notifyListeners();
      return _error;
    }

    final emailTrimmed = email.trim().toLowerCase();

    // 2. Check email not already in users collection
    final existingUid = await _fs.uidForEmail(emailTrimmed);
    if (existingUid != null) {
      _error = 'Email is already registered.';
      _isLoading = false;
      notifyListeners();
      return _error;
    }

    // 3. Create Auth account (signs in, then signs out)
    final uidResult = await _authService.registerResident(
      name: name.trim(),
      email: emailTrimmed,
      phone: phone.trim(),
      password: password,
      apt: apt,
      unit: unit.trim(),
    );

    if (uidResult.error != null) {
      _error = uidResult.error;
      _isLoading = false;
      notifyListeners();
      return _error;
    }

    // 4. Create resident_request doc
    await _fs.createResidentRequest({
      'name': name.trim(),
      'email': emailTrimmed,
      'phone': phone.trim(),
      'apartmentId': apt.id,
      'uid': uidResult.uid!,
      'unit': unit.trim(),
      'status': 'pending',
      'requestedAt': Timestamp.fromDate(DateTime.now()),
    });

    // 5. Notify apartment admin
    await notifProvider
        .addAndPersistNotification(
          title: 'New Resident Request',
          body:
              '${name.trim()} from Flat ${unit.trim()} has requested to join ${apt.name}.',
          type: 'resident_request',
          targetRole: UserRole.admin,
          aptId: apt.id,
        )
        .catchError((e) => debugPrint('[NOTIF] resident_request error: $e'));

    _isLoading = false;
    notifyListeners();
    return null; // null = success
  }

  // ── Admin approval / rejection ────────────────────────────────────────────

  /// Approves a resident request: creates users doc, increments occupiedFlats,
  /// notifies the resident, then deletes the request.
  Future<bool> approveRequest(
    ResidentRequestModel request,
    NotificationProvider notifProvider,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Compute avatar initials
      final words = request.name.trim().split(RegExp(r'\s+'));
      final initials = words
          .where((w) => w.isNotEmpty)
          .take(2)
          .map((w) => w[0].toUpperCase())
          .join();

      // 1. Create users doc using the stored UID from the request
      await _fs.createUser(request.uid, {
        'name': request.name,
        'email': request.email,
        'phone': request.phone,
        'role': 'user',
        'apartmentId': request.apartmentId,
        'unit': request.unit,
        'avatarInitials':
            initials.isEmpty ? request.name[0].toUpperCase() : initials,
        'isActive': true,
        'joinedAt': Timestamp.fromDate(DateTime.now()),
      });

      // 2. Increment apartment occupiedFlats
      await _fs.updateApartment(request.apartmentId, {
        'occupiedFlats': FieldValue.increment(1),
      });

      // 3. Notify the resident
      await notifProvider
          .addAndPersistNotification(
            title: 'Registration Approved',
            body:
                'Your registration has been approved! You can now log in to Maintify.',
            type: 'registration_approved',
            targetRole: UserRole.user,
            targetUserIds: [request.uid],
          )
          .catchError((e) => debugPrint('[NOTIF] approved error: $e'));

      // 4. Delete the request doc
      await _fs.deleteResidentRequest(request.id);

      // Optimistically remove from local list — don't wait for stream update
      _requests.removeWhere((r) => r.id == request.id);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[REGISTRATION] approveRequest error: $e');
      _error = 'Approval failed. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Rejects a resident request by deleting the request doc and notifying the
  /// resident. The Firebase Auth account remains but they cannot log in without
  /// a users doc.
  Future<bool> rejectRequest(
    ResidentRequestModel request,
    NotificationProvider notifProvider,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Notify the resident before deleting (uses their uid)
      await notifProvider
          .addAndPersistNotification(
            title: 'Registration Rejected',
            body:
                'Your registration request for Flat ${request.unit} has been rejected. Please contact the apartment president for more information.',
            type: 'registration_rejected',
            targetRole: UserRole.user,
            targetUserIds: [request.uid],
          )
          .catchError((e) => debugPrint('[NOTIF] rejected error: $e'));

      // 2. Delete the request doc
      await _fs.deleteResidentRequest(request.id);

      // Optimistically remove from local list — don't wait for stream update
      _requests.removeWhere((r) => r.id == request.id);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[REGISTRATION] rejectRequest error: $e');
      _error = 'Failed to reject request.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
