import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../models/user_model.dart';
import '../../models/apartment_model.dart';
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

  Future<void> createUser(String uid, Map<String, dynamic> data) =>
      _db.collection('users').doc(uid).set(data);

  Future<void> updateUser(String uid, Map<String, dynamic> data) =>
      _db.collection('users').doc(uid).update(data);

  /// Streams only the `activeSessionId` field from a user doc.
  /// Used by [AuthProvider] to detect logins from other devices.
  Stream<String?> streamUserSessionId(String uid) => _db
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.data()?['activeSessionId'] as String?);

  /// Admin-created user (no Firebase Auth yet). Stored in pending_users.
  Future<void> createPendingUser(Map<String, dynamic> data) =>
      _db.collection('pending_users').add(data);

  // ─────────────────────────────── APARTMENTS ─────────────────────────────────

  Stream<List<ApartmentModel>> streamApartments() => _db
      .collection('apartments')
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((s) => s.docs.map(ApartmentModel.fromFirestore).toList());

  Future<void> createApartment(String id, Map<String, dynamic> data) =>
      _db.collection('apartments').doc(id).set(data);

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

    // Promote new president
    batch.update(_db.collection('users').doc(newPresidentId), {
      'role': 'admin',
      'apartmentId': newPresidentApartmentId,
    });

    // Demote old president if different
    if (oldPresidentId != null && oldPresidentId != newPresidentId) {
      batch.update(_db.collection('users').doc(oldPresidentId), {
        'role': 'user',
      });
    }

    // Update apartment with both presidentId and presidentName
    batch.update(_db.collection('apartments').doc(aptId), {
      'presidentId': newPresidentId,
      'presidentName': newPresidentName,
    });

    await batch.commit();
  }

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

  /// Checks the Firestore SERVER directly (bypasses offline cache) to see if a
  /// bill already exists for [aptId] + [month]. Use this before creating a new
  /// monthly bill to avoid false positives from stale local cache.
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

  /// Deletes all payment documents for [billId] in a single batch.
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

  // ── Complaint messages (subcollection) ────────────────────────────────────

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

  /// Real-time stream of notifications for a specific user.
  /// Query: userId == currentUserId, ordered by createdAt desc.
  /// Requires composite index: userId ASC + createdAt DESC (see firestore.indexes.json).
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

  /// Deletes legacy notification documents that have a `targetRole` field but
  /// no `userId` field.  These are docs written before the per-user refactor;
  /// they will never match `where('userId', isEqualTo: ...)` queries.
  ///
  /// Safe to call on every login — it is a no-op when there is nothing to delete.
  Future<void> cleanupLegacyNotifications() async {
    // Query by the three known targetRole values — only legacy docs have this
    // field (new docs omit targetRole entirely).
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
    debugPrint('[CLEANUP] Deleted ${toDelete.length} legacy notification doc(s) (had targetRole, missing userId)');
  }
}
