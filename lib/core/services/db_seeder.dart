import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Seeds Firestore with minimal demo data for Google Play Internal Testing.
///
/// Guard document : `_meta/seeded_v4`
/// Seeds on first launch only; repairs the Admin account on subsequent launches.
///
/// ┌──────────────┬──────────────────────────────┬───────────────┐
/// │ Role         │ Email                        │ Password      │
/// ├──────────────┼──────────────────────────────┼───────────────┤
/// │ Admin        │ support.maintify@gmail.com   │ maintify@0606 │
/// │ President    │ president@maintify.demo      │ Maintify@123  │
/// │ Resident     │ resident@maintify.demo       │ Maintify@123  │
/// └──────────────┴──────────────────────────────┴───────────────┘
///
/// Apartment : Green Valley Residency (GRVL1234)
/// Flats     : 101 (President), 102 (Resident)
/// Bill      : 1 maintenance bill — current month, both pending
/// Complaint : 1 open complaint from Resident
/// Meeting   : 1 scheduled meeting
class DbSeeder {
  static final FirebaseFirestore _db   = FirebaseFirestore.instance;
  static final FirebaseAuth      _auth = FirebaseAuth.instance;

  static const _adminEmail     = 'support.maintify@gmail.com';
  static const _adminPassword  = 'maintify@0606';
  static const _presidentEmail = 'president@maintify.demo';
  static const _residentEmail  = 'resident@maintify.demo';
  static const _demoPassword   = 'Maintify@123';

  static const _aptId = 'apt_greenvalley';

  // ── Public entry point ─────────────────────────────────────────────────────

  static Future<void> seedIfNeeded() async {
    try {
      final meta = await _db.collection('_meta').doc('seeded_v4').get();
      if (meta.exists) {
        await _repairAdmin();
        return;
      }
      debugPrint('[DbSeeder] Seeding demo environment...');
      await _seedAll();
      debugPrint('[DbSeeder] Done.');
    } catch (e) {
      debugPrint('[DbSeeder] Error: $e');
    }
  }

  // ── Repair admin doc if accidentally deleted ───────────────────────────────

  static Future<void> _repairAdmin() async {
    try {
      final snap = await _db
          .collection('users')
          .where('email', isEqualTo: _adminEmail)
          .where('role', isEqualTo: 'admin')
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) return;

      debugPrint('[DbSeeder] Admin doc missing — recreating...');
      final cred = await _auth.signInWithEmailAndPassword(
        email: _adminEmail,
        password: _adminPassword,
      );
      await _writeAdminDoc(cred.user!.uid);
      await _auth.signOut();
      debugPrint('[DbSeeder] Admin doc recreated.');
    } catch (e) {
      debugPrint('[DbSeeder] _repairAdmin error: $e');
    }
  }

  // ── Full seed ──────────────────────────────────────────────────────────────

  static Future<void> _seedAll() async {
    final now = DateTime.now();

    // 1. Create Firebase Auth accounts
    final adminUid     = await _createAuthUser(_adminEmail,     _adminPassword);
    final presidentUid = await _createAuthUser(_presidentEmail, _demoPassword);
    final residentUid  = await _createAuthUser(_residentEmail,  _demoPassword);

    // Resolve UIDs (sign in if account already existed)
    final adminId     = adminUid     ?? await _signInUid(_adminEmail,     _adminPassword);
    final presidentId = presidentUid ?? await _signInUid(_presidentEmail, _demoPassword);
    final residentId  = residentUid  ?? await _signInUid(_residentEmail,  _demoPassword);

    if (presidentId == null || residentId == null) {
      debugPrint('[DbSeeder] Could not resolve UIDs — aborting seed.');
      return;
    }

    // 2. Sign in as admin so all subsequent Firestore writes satisfy isSuperAdmin().
    //    After creating 3 accounts sequentially, the last signed-in user is the
    //    resident; we need admin auth for apartment/bill/meeting writes.
    await _auth.signInWithEmailAndPassword(
      email: _adminEmail,
      password: _adminPassword,
    );

    // 3. Admin user doc (must exist in Firestore before batch so isSuperAdmin()
    //    rule can resolve the role via get()).
    if (adminId != null) await _writeAdminDoc(adminId);

    // 4. Apartment + President user doc + Resident user doc (single batch)
    final batch = _db.batch();

    batch.set(_db.collection('apartments').doc(_aptId), {
      'name':           'Green Valley Residency',
      'code':           'GRVL1234',
      'status':         'active',
      'type':           'Apartment',
      'address':        '12, Green Valley Road, Hyderabad - 500032',
      'totalFlats':     2,
      'towerCount':     0,
      'towerNames':     [],
      'presidentId':    presidentId,
      'presidentName':  'Arjun Sharma',
      'presidentEmail': _presidentEmail,
      'presidentPhone': '+91 98765 10001',
      'presidentFlat':  '101',
      'occupiedFlats':  2,
      'createdAt':      Timestamp.fromDate(now),
      'updatedAt':      Timestamp.fromDate(now),
    });

    batch.set(_db.collection('users').doc(presidentId), {
      'name':           'Arjun Sharma',
      'email':          _presidentEmail,
      'phone':          '+91 98765 10001',
      'role':           'president',
      'apartmentId':    _aptId,
      'unit':           '101',
      'avatarInitials': 'AS',
      'isActive':       true,
      'joinedAt':       Timestamp.fromDate(now),
    });

    batch.set(_db.collection('users').doc(residentId), {
      'name':           'Ravi Kumar',
      'email':          _residentEmail,
      'phone':          '+91 98765 20001',
      'role':           'resident',
      'apartmentId':    _aptId,
      'unit':           '102',
      'avatarInitials': 'RK',
      'isActive':       true,
      'joinedAt':       Timestamp.fromDate(now),
    });

    // 4. Flat 101 — President
    batch.set(_db.collection('flats').doc('${_aptId}_101'), {
      'flatNumber':   '101',
      'tower':        null,
      'status':       'occupied',
      'residentId':   presidentId,
      'residentType': 'President',
      'apartmentId':  _aptId,
      'updatedAt':    Timestamp.fromDate(now),
    });

    // 5. Flat 102 — Resident
    batch.set(_db.collection('flats').doc('${_aptId}_102'), {
      'flatNumber':   '102',
      'tower':        null,
      'status':       'occupied',
      'residentId':   residentId,
      'residentType': 'Resident',
      'apartmentId':  _aptId,
      'updatedAt':    Timestamp.fromDate(now),
    });

    await batch.commit();

    // 6. Bill — current month maintenance, both pending
    await _seedBill(presidentId, residentId, now);

    // 7. Complaint — one open complaint from Resident
    await _seedComplaint(residentId, now);

    // 8. Meeting — one upcoming scheduled meeting
    await _seedMeeting(presidentId, now);

    // 9. Guard doc
    await _db.collection('_meta').doc('seeded_v4').set({
      'seededAt': Timestamp.fromDate(now),
      'version':  4,
    });

    // 10. Sign back in as Admin so the app loads the Admin dashboard
    if (adminId != null) {
      await _auth.signInWithEmailAndPassword(
        email: _adminEmail,
        password: _adminPassword,
      );
    }
  }

  // ── Bill ───────────────────────────────────────────────────────────────────

  static Future<void> _seedBill(
    String presidentId,
    String residentId,
    DateTime now,
  ) async {
    final billRef = _db.collection('bills').doc();
    final billId  = billRef.id;
    final dueDate = DateTime(now.year, now.month + 1, 5);

    final batch = _db.batch();

    batch.set(billRef, {
      'apartmentId':   _aptId,
      'month':         Timestamp.fromDate(DateTime(now.year, now.month)),
      'categories': [
        {
          'name':          'Maintenance',
          'totalAmount':   2000.0,
          'splitType':     'common',
          'userOverrides': <String, dynamic>{},
        },
      ],
      'eligibleCount':   2,
      'excludedUserIds': [],
      'dueDate':         Timestamp.fromDate(dueDate),
      'createdAt':       Timestamp.fromDate(now),
      'createdBy':       presidentId,
    });

    // President payment — pending
    batch.set(_db.collection('payments').doc('${billId}_$presidentId'), {
      'billId':      billId,
      'userId':      presidentId,
      'apartmentId': _aptId,
      'flatNumber':  '101',
      'amount':      1000.0,
      'status':      'pending',
      'paidAt':      null,
      'approvedAt':  null,
      'proofUrl':    null,
    });

    // Resident payment — pending
    batch.set(_db.collection('payments').doc('${billId}_$residentId'), {
      'billId':      billId,
      'userId':      residentId,
      'apartmentId': _aptId,
      'flatNumber':  '102',
      'amount':      1000.0,
      'status':      'pending',
      'paidAt':      null,
      'approvedAt':  null,
      'proofUrl':    null,
    });

    await batch.commit();
  }

  // ── Complaint ──────────────────────────────────────────────────────────────

  static Future<void> _seedComplaint(String residentId, DateTime now) async {
    await _db.collection('complaints').doc().set({
      'apartmentId':    _aptId,
      'userId':         residentId,
      'userName':       'Ravi Kumar',
      'unit':           '102',
      'category':       'Maintenance',
      'title':          'Water leakage in kitchen',
      'status':         'Open',           // must match ComplaintStatus.open
      'createdAt':      Timestamp.fromDate(now),
      'lastActivityAt': Timestamp.fromDate(now), // correct field name used by the app
    });
  }

  // ── Meeting ────────────────────────────────────────────────────────────────

  static Future<void> _seedMeeting(String presidentId, DateTime now) async {
    await _db.collection('meetings').doc().set({
      'apartmentId': _aptId,
      'title':       'Monthly Apartment Meeting',
      'description': 'Discussion on maintenance charges and common area upkeep.',
      'scheduledAt': Timestamp.fromDate(now.add(const Duration(days: 7))),
      'venue':       'Community Hall, Ground Floor',
      'status':      'scheduled',
      'createdBy':   presidentId,
      'createdAt':   Timestamp.fromDate(now),
    });
  }

  // ── Admin user doc ─────────────────────────────────────────────────────────

  static Future<void> _writeAdminDoc(String uid) async {
    await _db.collection('users').doc(uid).set({
      'name':           'Maintify Admin',
      'email':          _adminEmail,
      'phone':          '+91 00000 00000',
      'role':           'admin',
      'apartmentId':    null,
      'unit':           'HQ',
      'avatarInitials': 'MA',
      'isActive':       true,
      'joinedAt':       Timestamp.fromDate(DateTime(2024, 1, 1)),
    });
  }

  // ── Firebase Auth helpers ──────────────────────────────────────────────────

  /// Creates a Firebase Auth account. Returns UID, or null if already exists.
  static Future<String?> _createAuthUser(String email, String password) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return cred.user?.uid;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') return null;
      debugPrint('[DbSeeder] _createAuthUser($email): ${e.code}');
      return null;
    }
  }

  /// Signs in and returns the UID. Used to retrieve UIDs for existing accounts.
  static Future<String?> _signInUid(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return cred.user?.uid;
    } catch (e) {
      debugPrint('[DbSeeder] _signInUid($email): $e');
      return null;
    }
  }
}
