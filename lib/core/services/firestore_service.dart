import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../ads/ad_config.dart';
import '../../models/user_model.dart';
import '../../models/apartment_model.dart';
import '../../models/flat_model.dart';
import '../../models/bill_model.dart';
import '../../models/complaint_model.dart';
import '../../models/meeting_model.dart';
import '../../models/notification_model.dart';
import '../../models/president_invitation_model.dart';
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

  Future<void> deleteUser(String uid) =>
      _db.collection('users').doc(uid).delete();

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

  Future<void> deleteApartment(String aptId) =>
      _db.collection('apartments').doc(aptId).delete();

  /// Hard-deletes an apartment and every Firestore document that belongs to it:
  /// users, notifications, complaints + messages, bills, payments, meetings,
  /// flats, president_invitations, and the apartment doc itself.
  ///
  /// Note: Firebase Auth accounts are NOT deleted (requires Admin SDK /
  /// Cloud Functions with billing). Deleted members will be unable to log in
  /// because their Firestore user doc is removed — signIn returns
  /// "Account data not found".
  Future<void> deleteApartmentFull(String aptId) async {
    // 1. Collect all member UIDs
    final usersSnap = await _db
        .collection('users')
        .where('apartmentId', isEqualTo: aptId)
        .get();
    final memberUids = usersSnap.docs.map((d) => d.id).toList();

    // 2. Delete notifications for each member
    for (final uid in memberUids) {
      final notifSnap = await _db
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .get();
      await _batchDeleteDocs(notifSnap.docs);
    }

    // 3. Delete Firestore user docs
    await _batchDeleteDocs(usersSnap.docs);

    // 4. Delete complaints + their messages subcollection
    final complaintsSnap = await _db
        .collection('complaints')
        .where('apartmentId', isEqualTo: aptId)
        .get();
    for (final cDoc in complaintsSnap.docs) {
      final msgSnap = await cDoc.reference.collection('messages').get();
      await _batchDeleteDocs(msgSnap.docs);
    }
    await _batchDeleteDocs(complaintsSnap.docs);

    // 5. Delete bills
    final billsSnap = await _db
        .collection('bills')
        .where('apartmentId', isEqualTo: aptId)
        .get();
    await _batchDeleteDocs(billsSnap.docs);

    // 6. Delete payments
    final paymentsSnap = await _db
        .collection('payments')
        .where('apartmentId', isEqualTo: aptId)
        .get();
    await _batchDeleteDocs(paymentsSnap.docs);

    // 7. Delete meetings
    final meetingsSnap = await _db
        .collection('meetings')
        .where('apartmentId', isEqualTo: aptId)
        .get();
    await _batchDeleteDocs(meetingsSnap.docs);

    // 8. Delete flats
    await deleteFlatsForApartment(aptId);

    // 9. Delete president_invitations
    final invSnap = await _db
        .collection('president_invitations')
        .where('apartmentId', isEqualTo: aptId)
        .get();
    await _batchDeleteDocs(invSnap.docs);

    // 10. Delete the apartment doc itself
    await deleteApartment(aptId);
  }

  /// Batch-deletes a list of Firestore docs in chunks of 400.
  Future<void> _batchDeleteDocs(List<QueryDocumentSnapshot> docs) async {
    if (docs.isEmpty) return;
    const chunkSize = 400;
    for (int i = 0; i < docs.length; i += chunkSize) {
      final end = (i + chunkSize) < docs.length ? i + chunkSize : docs.length;
      final batch = _db.batch();
      for (final doc in docs.sublist(i, end)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  /// Batch-deletes all flat documents belonging to an apartment.
  Future<void> deleteFlatsForApartment(String aptId) async {
    final snap = await _db
        .collection('flats')
        .where('apartmentId', isEqualTo: aptId)
        .get();
    if (snap.docs.isEmpty) return;
    const chunkSize = 400;
    for (int i = 0; i < snap.docs.length; i += chunkSize) {
      final end = (i + chunkSize) < snap.docs.length
          ? (i + chunkSize)
          : snap.docs.length;
      final batch = _db.batch();
      for (final doc in snap.docs.sublist(i, end)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  /// Clears resident info from a flat (marks it available).
  Future<void> clearFlatResident(String flatId) =>
      _db.collection('flats').doc(flatId).update({
        'status': 'available',
        'residentId': null,
        'residentType': null,
      });

  /// Soft-removes all members of an apartment: clears apartmentId + deactivates.
  Future<void> disengageUsersFromApartment(String aptId) async {
    final snap = await _db
        .collection('users')
        .where('apartmentId', isEqualTo: aptId)
        .get();
    if (snap.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {
        'apartmentId': null,
        'unit': '',
        'isActive': false,
      });
    }
    await batch.commit();
  }

  /// Finds the real admin user for an apartment (used for pending_* migration).
  Future<UserModel?> findAdminForApartment(String aptId) async {
    final snap = await _db
        .collection('users')
        .where('apartmentId', isEqualTo: aptId)
        .where('role', isEqualTo: 'president')
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
      'role': 'president',
      'apartmentId': newPresidentApartmentId,
    });

    if (oldPresidentId != null && oldPresidentId != newPresidentId) {
      batch.update(_db.collection('users').doc(oldPresidentId), {
        'role': 'resident',
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
          // No server-side orderBy — that would require a composite index on
          // (apartmentId, lastActivityAt) which may not exist in every
          // environment. We sort client-side after deserialisation instead.
          .snapshots()
          .map((s) {
            final list =
                s.docs.map(ComplaintModel.fromFirestore).toList();
            list.sort(
                (a, b) => b.lastActivityAt.compareTo(a.lastActivityAt));
            return list;
          });

  Stream<List<ComplaintModel>> streamComplaintsForUser(String userId) => _db
      .collection('complaints')
      .where('userId', isEqualTo: userId)
      // Same reason: avoid requiring a composite index on (userId, lastActivityAt).
      .snapshots()
      .map((s) {
        final list = s.docs.map(ComplaintModel.fromFirestore).toList();
        list.sort((a, b) => b.lastActivityAt.compareTo(a.lastActivityAt));
        return list;
      });

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
        .where('targetRole', whereIn: ['resident', 'president', 'admin'])
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

  // ──────────────────────── PRESIDENT INVITATIONS ──────────────────────────────

  /// Generates a unique 12-char alphanumeric invitation token (uppercase).
  String generateInvitationToken() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(12, (_) => chars[_rng.nextInt(chars.length)]).join();
  }

  /// Creates a president invitation document. Returns the new document ID.
  Future<String> createPresidentInvitation(Map<String, dynamic> data) async {
    final ref = await _db.collection('president_invitations').add(data);
    return ref.id;
  }

  /// Fetches an invitation by its token. Returns null if not found.
  Future<PresidentInvitationModel?> getInvitationByToken(String token) async {
    final snap = await _db
        .collection('president_invitations')
        .where('invitationToken', isEqualTo: token.trim().toUpperCase())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return PresidentInvitationModel.fromFirestore(snap.docs.first);
  }

  Future<void> updateInvitation(String id, Map<String, dynamic> data) =>
      _db.collection('president_invitations').doc(id).update(data);

  /// Atomically activates a president:
  ///  • Creates the users/{uid} doc
  ///  • Sets apartment status → 'active', links presidentId
  ///  • Marks invitation as 'completed'
  ///
  /// Call [updateFlat] separately after this batch completes.
  Future<void> activatePresidentBatch({
    required String uid,
    required PresidentInvitationModel invitation,
  }) async {
    final now    = DateTime.now();
    final words  = invitation.presidentName.trim().split(RegExp(r'\s+'));
    final initials = words
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    final batch = _db.batch();

    // Create president user doc
    batch.set(_db.collection('users').doc(uid), {
      'name':           invitation.presidentName,
      'email':          invitation.presidentEmail,
      'phone':          invitation.mobileNumber,
      'role':           'president',
      'apartmentId':    invitation.apartmentId,
      'unit':           invitation.presidentFlatNumber,
      'avatarInitials': initials.isEmpty
          ? invitation.presidentName[0].toUpperCase()
          : initials,
      'isActive':       true,
      'joinedAt':       Timestamp.fromDate(now),
    });

    // Activate apartment + link president
    batch.update(_db.collection('apartments').doc(invitation.apartmentId), {
      'status':        'active',
      'presidentId':   uid,
      'presidentName': invitation.presidentName,
      'occupiedFlats': FieldValue.increment(1),
      'updatedAt':     Timestamp.fromDate(now),
    });

    // Mark invitation as completed
    batch.update(
      _db.collection('president_invitations').doc(invitation.id),
      {
        'status':      'completed',
        'presidentId': uid,
        'activatedAt': Timestamp.fromDate(now),
      },
    );

    await batch.commit();
  }

  // ──────────────────────── WELCOME EMAIL TRIGGER ───────────────────────────────

  /// Sets `welcomeEmailReady: true` on the user doc.
  /// The Cloud Function `onWelcomeEmailReady` picks this up and sends the email
  /// once — it uses `welcomeEmailSentAt` for idempotency.
  Future<void> setWelcomeEmailReady(String userId) =>
      _db.collection('users').doc(userId).update({'welcomeEmailReady': true});

  // ─────────────────────────────── ADS CONFIG ─────────────────────────────────
  // Firestore path: systemConfig/adManagement
  // Schema: { adsEnabled, banner:{enabled}, interstitial:{enabled,frequency,cooldownSeconds},
  //           native:{enabled}, updatedAt, updatedBy }

  /// Streams the full ad configuration from [systemConfig/adManagement].
  /// Emits an [AdConfig.defaultOff()] (everything disabled) when the document
  /// does not exist or cannot be read — ads are never accidentally enabled.
  Stream<AdConfig> streamAdConfig() {
    return _db
        .collection('systemConfig')
        .doc('adManagement')
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return AdConfig.defaultOff();
      try {
        return AdConfig.fromMap(doc.data()!);
      } catch (_) {
        return AdConfig.defaultOff();
      }
    });
  }

  /// Streams only the apartment-level adsEnabled field.
  /// Emits [false] (ads OFF) when the field is absent or the document missing.
  Stream<bool> streamApartmentAdsConfig(String aptId) {
    return _db.collection('apartments').doc(aptId).snapshots().map((doc) {
      if (!doc.exists) return false;
      return (doc.data()?['adsEnabled'] as bool?) ?? false;
    });
  }

  /// Writes/merges the full ad configuration (super admin only).
  Future<void> updateAdConfig(AdConfig config, {required String updatedBy}) {
    return _db
        .collection('systemConfig')
        .doc('adManagement')
        .set(config.toMap(updatedBy: updatedBy), SetOptions(merge: true));
  }

  /// Fetches the current ad configuration once (non-streaming).
  Future<AdConfig> getAdConfig() async {
    try {
      final doc = await _db
          .collection('systemConfig')
          .doc('adManagement')
          .get();
      if (!doc.exists || doc.data() == null) return AdConfig.defaultOff();
      return AdConfig.fromMap(doc.data()!);
    } catch (_) {
      return AdConfig.defaultOff();
    }
  }

  /// Updates only the adsEnabled field in an apartment document.
  /// Called by both super admin and president.
  Future<void> updateApartmentAdsEnabled({
    required String aptId,
    required bool adsEnabled,
    required String updatedBy,
  }) {
    return _db.collection('apartments').doc(aptId).update({
      'adsEnabled': adsEnabled,
      'adsUpdatedAt': FieldValue.serverTimestamp(),
      'adsUpdatedBy': updatedBy,
    });
  }
}
