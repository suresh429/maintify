import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/user_model.dart';
import '../../models/apartment_model.dart';
import '../../models/flat_model.dart';
import '../../models/bill_model.dart';
import '../../models/complaint_model.dart';
import '../../models/meeting_model.dart';
import '../../models/notification_model.dart';
import '../../core/theme/role_theme.dart';

/// Central Firestore service — all collection reads/writes go through here.
/// Providers depend on this service, never on FirebaseFirestore directly.
class FirestoreService {
  static final FirestoreService _instance = FirestoreService._();
  factory FirestoreService() => _instance;
  FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _rng = Random();

  // ─────────────────────────────────── USERS ──────────────────────────────────

  Stream<List<UserModel>> streamUsers() => _db
      .collection('users')
      .snapshots()
      .map((s) => s.docs.map(UserModel.fromFirestore).toList());

  Stream<List<UserModel>> streamUsersForApartment(String aptId) => _db
      .collection('users')
      .where('apartmentId', isEqualTo: aptId)
      .snapshots()
      .map((s) => s.docs.map(UserModel.fromFirestore).toList());

  /// One-time fetch — used to resolve notification targets without a stream.
  Future<List<UserModel>> getUsersForApartment(String aptId,
      {UserRole? role}) async {
    var query = _db
        .collection('users')
        .where('apartmentId', isEqualTo: aptId);
    if (role != null) {
      query = query.where('role', isEqualTo: role.name);
    }
    final snap = await query.get();
    return snap.docs.map(UserModel.fromFirestore).toList();
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists ? UserModel.fromFirestore(doc) : null;
  }

  Future<String?> uidForEmail(String email) async {
    final snap = await _db
        .collection('users')
        .where('email', isEqualTo: email.trim().toLowerCase())
        .limit(1)
        .get();
    return snap.docs.isEmpty ? null : snap.docs.first.id;
  }

  /// Returns true if the given phone number is already registered.
  Future<bool> phoneExists(String phone) async {
    if (phone.trim().isEmpty) return false;
    final snap = await _db
        .collection('users')
        .where('phone', isEqualTo: phone.trim())
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<void> createUser(String uid, Map<String, dynamic> data) =>
      _db.collection('users').doc(uid).set(data);

  Future<void> updateUser(String uid, Map<String, dynamic> data) =>
      _db.collection('users').doc(uid).update(data);

  /// Streams only the `activeSessionId` field from a user doc.
  Stream<String?> streamUserSessionId(String uid) => _db
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.data()?['activeSessionId'] as String?);

  // ─────────────────────────────── APARTMENTS ─────────────────────────────────

  /// Finds an apartment by its unique apartment code (case-sensitive).
  Future<ApartmentModel?> findApartmentByCode(String code) async {
    var snap = await _db
        .collection('apartments')
        .where('code', isEqualTo: code)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) {
      snap = await _db
          .collection('apartments')
          .where('apartmentCode', isEqualTo: code)
          .limit(1)
          .get();
    }
    if (snap.docs.isEmpty) return null;
    return ApartmentModel.fromFirestore(snap.docs.first);
  }

  Stream<List<ApartmentModel>> streamApartments() => _db
      .collection('apartments')
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((s) => s.docs.map(ApartmentModel.fromFirestore).toList());

  Future<void> createApartment(String id, Map<String, dynamic> data) =>
      _db.collection('apartments').doc(id).set(data);

  /// Returns true if an apartment with the same name, address, and optional
  /// type already exists. Prevents duplicate apartment creation.
  Future<bool> apartmentExists({
    required String name,
    required String address,
    String? type,
  }) async {
    if (address.trim().isEmpty) return false;
    var query = _db
        .collection('apartments')
        .where('name', isEqualTo: name)
        .where('address', isEqualTo: address);
    if (type != null && type.isNotEmpty) {
      query = query.where('type', isEqualTo: type);
    }
    final snap = await query.limit(1).get();
    return snap.docs.isNotEmpty;
  }

  /// Returns true if an apartment code already exists (used for unique-code retry).
  Future<bool> apartmentCodeExists(String code) async {
    final snap = await _db
        .collection('apartments')
        .where('code', isEqualTo: code)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  /// Generates a collision-safe 8-char apartment code: 4 letters + 4 digits.
  Future<String> generateUniqueApartmentCode(String aptName) async {
    final clean = aptName.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    final letters = clean.length >= 4
        ? clean.substring(0, 4)
        : clean.padRight(4, 'X');
    String code;
    do {
      final digits = (1000 + _rng.nextInt(9000)).toString();
      code = '$letters$digits';
    } while (await apartmentCodeExists(code));
    return code;
  }

  Future<void> updateApartment(String id, Map<String, dynamic> data) =>
      _db.collection('apartments').doc(id).update(data);

  /// Finds the real admin user for an apartment (used for pending_* migration).
  Future<UserModel?> findAdminForApartment(String aptId) async {
    final snap = await _db
        .collection('users')
        .where('apartmentId', isEqualTo: aptId)
        .where('role', isEqualTo: 'admin')
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return UserModel.fromFirestore(snap.docs.first);
  }

  /// Atomically updates the apartment's presidentId/presidentName AND user roles.
  Future<void> assignPresidentBatch({
    required String aptId,
    required String newPresidentId,
    required String newPresidentName,
    required String newPresidentApartmentId,
    String? oldPresidentId,
  }) async {
    final batch = _db.batch();

    batch.update(_db.collection('users').doc(newPresidentId), {
      'role': 'admin',
      'apartmentId': newPresidentApartmentId,
    });

    if (oldPresidentId != null && oldPresidentId != newPresidentId) {
      batch.update(_db.collection('users').doc(oldPresidentId), {
        'role': 'user',
      });
    }

    batch.update(_db.collection('apartments').doc(aptId), {
      'presidentId': newPresidentId,
      'presidentName': newPresidentName,
    });

    await batch.commit();
  }

  // ─────────────────────────────────── FLATS ───────────────────────────────────

  /// Batch-creates all flats for a new apartment. Chunked at 500 per batch.
  Future<void> createFlats(List<FlatModel> flats) async {
    const chunkSize = 400;
    for (int i = 0; i < flats.length; i += chunkSize) {
      final chunk = flats.sublist(
          i, (i + chunkSize) < flats.length ? (i + chunkSize) : flats.length);
      final batch = _db.batch();
      for (final flat in chunk) {
        batch.set(_db.collection('flats').doc(flat.id), flat.toMap());
      }
      await batch.commit();
    }
  }

  /// Finds a flat by its number inside an apartment.
  Future<FlatModel?> getFlatByNumber(String aptId, String flatNumber) async {
    final snap = await _db
        .collection('flats')
        .where('apartmentId', isEqualTo: aptId)
        .where('flatNumber', isEqualTo: flatNumber)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return FlatModel.fromFirestore(snap.docs.first);
  }

  Future<void> updateFlat(String flatId, Map<String, dynamic> data) =>
      _db.collection('flats').doc(flatId).update(data);

  Stream<List<FlatModel>> streamFlatsForApartment(String aptId) => _db
      .collection('flats')
      .where('apartmentId', isEqualTo: aptId)
      .orderBy('flatNumber')
      .snapshots()
      .map((s) => s.docs.map(FlatModel.fromFirestore).toList());

  // ──────────────────────────────────── BILLS ──────────────────────────────────

  Stream<List<BillModel>> streamBillsForApartment(String aptId) => _db
      .collection('bills')
      .where('apartmentId', isEqualTo: aptId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(BillModel.fromFirestore).toList());

  Stream<List<BillModel>> streamAllBills() => _db
      .collection('bills')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(BillModel.fromFirestore).toList());

  Future<DocumentReference> createBill(Map<String, dynamic> data) =>
      _db.collection('bills').add(data);

  Future<void> setBill(String id, Map<String, dynamic> data) =>
      _db.collection('bills').doc(id).set(data);

  Future<bool> monthlyBillExistsOnServer(String aptId, String month) async {
    final snap = await _db
        .collection('bills')
        .where('apartmentId', isEqualTo: aptId)
        .where('month', isEqualTo: month)
        .limit(1)
        .get(const GetOptions(source: Source.server));
    return snap.docs.isNotEmpty;
  }

  Future<void> updateBill(String id, Map<String, dynamic> data) =>
      _db.collection('bills').doc(id).update(data);

  Future<void> deleteBill(String id) =>
      _db.collection('bills').doc(id).delete();

  Future<void> deleteAllPaymentsForBill(String billId) async {
    final snap = await _db
        .collection('payments')
        .where('billId', isEqualTo: billId)
        .get();
    if (snap.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ─────────────────────────────────── PAYMENTS ────────────────────────────────

  Stream<List<BillPayment>> streamPaymentsForApartment(String aptId) => _db
      .collection('payments')
      .where('apartmentId', isEqualTo: aptId)
      .snapshots()
      .map((s) => s.docs.map(BillPayment.fromFirestore).toList());

  Stream<List<BillPayment>> streamPaymentsForUser(String userId) => _db
      .collection('payments')
      .where('userId', isEqualTo: userId)
      .snapshots()
      .map((s) => s.docs.map(BillPayment.fromFirestore).toList());

  Future<void> setPayment(String id, Map<String, dynamic> data) =>
      _db.collection('payments').doc(id).set(data);

  Future<void> updatePayment(String id, Map<String, dynamic> data) =>
      _db.collection('payments').doc(id).update(data);

  // ─────────────────────────────────── COMPLAINTS ──────────────────────────────

  Stream<List<ComplaintModel>> streamComplaintsForApartment(String aptId) =>
      _db
          .collection('complaints')
          .where('apartmentId', isEqualTo: aptId)
          .orderBy('lastActivityAt', descending: true)
          .snapshots()
          .map((s) => s.docs.map(ComplaintModel.fromFirestore).toList());

  Stream<List<ComplaintModel>> streamComplaintsForUser(String userId) => _db
      .collection('complaints')
      .where('userId', isEqualTo: userId)
      .orderBy('lastActivityAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(ComplaintModel.fromFirestore).toList());

  Future<void> createComplaint(String id, Map<String, dynamic> data) =>
      _db.collection('complaints').doc(id).set(data);

  Future<void> updateComplaint(String id, Map<String, dynamic> data) =>
      _db.collection('complaints').doc(id).update(data);

  Stream<List<ComplaintMessage>> streamMessages(String complaintId) => _db
      .collection('complaints')
      .doc(complaintId)
      .collection('messages')
      .orderBy('timestamp')
      .snapshots()
      .map((s) => s.docs.map(ComplaintMessage.fromFirestore).toList());

  Future<void> addMessage(
          String complaintId, Map<String, dynamic> data) =>
      _db
          .collection('complaints')
          .doc(complaintId)
          .collection('messages')
          .add(data);

  // ─────────────────────────────────── MEETINGS ────────────────────────────────

  Stream<List<MeetingModel>> streamMeetingsForApartment(String aptId) => _db
      .collection('meetings')
      .where('apartmentId', isEqualTo: aptId)
      .orderBy('scheduledAt')
      .snapshots()
      .map((s) => s.docs.map(MeetingModel.fromFirestore).toList());

  Future<DocumentReference> createMeeting(Map<String, dynamic> data) =>
      _db.collection('meetings').add(data);

  // ─────────────────────────────────── NOTIFICATIONS ───────────────────────────

  Stream<List<NotificationModel>> streamNotificationsForUser(String userId) =>
      _db
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots()
          .map((s) => s.docs.map(NotificationModel.fromFirestore).toList());

  Future<void> addNotification(Map<String, dynamic> data) =>
      _db.collection('notifications').add(data);

  Future<void> markNotificationRead(String id) =>
      _db.collection('notifications').doc(id).update({'isRead': true});

  Future<void> markAllNotificationsReadForUser(String userId) async {
    final snap = await _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> cleanupLegacyNotifications() async {
    final snap = await _db
        .collection('notifications')
        .where('targetRole', whereIn: ['user', 'admin', 'superAdmin'])
        .limit(200)
        .get();

    final toDelete =
        snap.docs.where((d) => (d.data()['userId'] as String?) == null).toList();

    if (toDelete.isEmpty) {
      debugPrint('[CLEANUP] No legacy notification docs found — nothing to delete');
      return;
    }

    final batch = _db.batch();
    for (final doc in toDelete) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    debugPrint('[CLEANUP] Deleted ${toDelete.length} legacy notification doc(s)');
  }

  // ─────────────────────────────────── MAIL ────────────────────────────────────

  Future<void> sendEmail(Map<String, dynamic> data) =>
      _db.collection('mail').add(data);
}
