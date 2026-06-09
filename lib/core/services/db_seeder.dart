import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../models/user_model.dart';
import '../../models/apartment_model.dart';
import '../../models/bill_model.dart';
import '../../models/complaint_model.dart';
import '../../models/meeting_model.dart';
import '../../core/theme/role_theme.dart';

/// Seeds Firestore with the mock test data on first app launch.
/// Guards against re-seeding using a `_meta/seeded` document.
///
/// After seeding, the following accounts are available:
///   superadmin@test.com / 123456  → Super Admin
///   admin@test.com       / 123456  → Admin (G. Srikanth, Flat 402)
///   user@test.com        / 123456  → User (Rohit, Flat 101)
///   (+ 8 more residents, password 123456)
class DbSeeder {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // mockId → firebase UID, populated during seeding
  static final Map<String, String> _uidMap = {};

  static Future<void> seedIfNeeded() async {
    try {
      final meta = await _db.collection('_meta').doc('seeded').get();
      if (meta.exists) return;
      if (kDebugMode) debugPrint('[DbSeeder] Seeding Firestore...');
      await _seed();
      if (kDebugMode) debugPrint('[DbSeeder] Done.');
    } catch (e) {
      if (kDebugMode) debugPrint('[DbSeeder] Error: $e');
    }
  }

  static Future<void> _seed() async {
    // 1. Create Auth + Firestore user documents
    await _seedUsers();

    // 2. Seed apartment (use real UIDs for presidentId)
    await _seedApartments();

    // 3. Seed bills
    await _seedBills();

    // 4. Seed payments
    await _seedPayments();

    // 5. Seed complaints + messages
    await _seedComplaints();

    // 6. Seed meetings
    await _seedMeetings();

    // Mark seeded
    await _db.collection('_meta').doc('seeded').set({
      'timestamp': FieldValue.serverTimestamp(),
      'version': 1,
    });

    // Re-sign in as super admin so the app can continue
    await _auth.signInWithEmailAndPassword(
      email: 'superadmin@test.com',
      password: '123456',
    );
  }

  // ─────────────────────────────────── USERS ──────────────────────────────────

  static Future<void> _seedUsers() async {
    final batch = _db.batch();
    for (final user in MockUsers.all) {
      try {
        final cred = await _auth.createUserWithEmailAndPassword(
          email: user.email,
          password: '123456',
        );
        _uidMap[user.id] = cred.user!.uid;
        final ref = _db.collection('users').doc(cred.user!.uid);
        batch.set(ref, {
          'name': user.name,
          'email': user.email,
          'phone': user.phone,
          'role': user.role.name,
          'apartmentId': user.apartmentId,
          'unit': user.unit,
          'avatarInitials': user.avatarInitials,
          'isActive': user.isActive,
          'isFirstLogin': user.isFirstLogin,
          'joinedAt': Timestamp.fromDate(user.joinedAt),
        });
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          // Account exists — look up the uid via sign-in
          try {
            final cred = await _auth.signInWithEmailAndPassword(
              email: user.email,
              password: '123456',
            );
            _uidMap[user.id] = cred.user!.uid;
          } catch (_) {}
        }
      }
    }
    await batch.commit();
  }

  // ─────────────────────────────── APARTMENTS ─────────────────────────────────

  static Future<void> _seedApartments() async {
    for (final apt in MockApartments.all) {
      await _db.collection('apartments').doc(apt.id).set({
        'name': apt.name,
        'address': apt.address,
        'city': apt.city,
        'totalFlats': apt.totalFlats,
        'presidentId': _uidMap[apt.presidentId] ?? apt.presidentId,
        'amenities': apt.amenities,
        'createdAt': Timestamp.fromDate(apt.createdAt),
      });
    }
  }

  // ──────────────────────────────────── BILLS ──────────────────────────────────

  static Future<void> _seedBills() async {
    for (final bill in MockBillData.bills) {
      await _db.collection('bills').doc(bill.id).set({
        'apartmentId': bill.apartmentId,
        'createdByAdminId':
            _uidMap[bill.createdByAdminId] ?? bill.createdByAdminId,
        'title': bill.title,
        'totalAmount': bill.totalAmount,
        'totalFlats': bill.totalFlats,
        'category': bill.category,
        'month': bill.month,
        'dueDate': Timestamp.fromDate(bill.dueDate),
        'createdAt': Timestamp.fromDate(bill.createdAt),
      });
    }
  }

  // ─────────────────────────────────── PAYMENTS ────────────────────────────────

  static Future<void> _seedPayments() async {
    final batch = _db.batch();

    // Resolve apartmentId for each bill
    final billAptMap = {
      for (final b in MockBillData.bills) b.id: b.apartmentId
    };

    for (final p in MockBillData.payments) {
      final ref = _db.collection('payments').doc(p.id);
      batch.set(ref, {
        'billId': p.billId,
        'userId': _uidMap[p.userId] ?? p.userId,
        'unitNumber': p.unitNumber,
        'status': p.status,
        'paidDate':
            p.paidDate != null ? Timestamp.fromDate(p.paidDate!) : null,
        'transactionId': p.transactionId,
        'adminVerified': p.adminVerified,
        'apartmentId': billAptMap[p.billId] ?? 'apt1',
      });
    }
    await batch.commit();
  }

  // ─────────────────────────────────── COMPLAINTS ──────────────────────────────

  static Future<void> _seedComplaints() async {
    for (final c in MockComplaints.all) {
      final ref = _db.collection('complaints').doc(c.id);
      await ref.set({
        'apartmentId': c.apartmentId,
        'userId': _uidMap[c.userId] ?? c.userId,
        'userName': c.userName,
        'unit': c.unit,
        'title': c.title,
        'category': c.category,
        'status': c.status,
        'createdAt': Timestamp.fromDate(c.createdAt),
        'lastActivityAt': Timestamp.fromDate(c.lastActivityAt),
      });

      // Seed messages as subcollection
      for (final m in c.messages) {
        await ref.collection('messages').doc(m.id).set({
          'complaintId': c.id,
          'senderId': _uidMap[m.senderId] ?? m.senderId,
          'senderName': m.senderName,
          'isFromAdmin': m.isFromAdmin,
          'content': m.content,
          'timestamp': Timestamp.fromDate(m.timestamp),
        });
      }
    }
  }

  // ─────────────────────────────────── MEETINGS ────────────────────────────────

  static Future<void> _seedMeetings() async {
    for (final m in MockMeetings.all) {
      await _db.collection('meetings').doc(m.id).set({
        'apartmentId': m.apartmentId,
        'title': m.title,
        'description': m.description,
        'scheduledAt': Timestamp.fromDate(m.scheduledAt),
        'createdByAdminId':
            _uidMap[m.createdByAdminId] ?? m.createdByAdminId,
      });
    }
  }
}
