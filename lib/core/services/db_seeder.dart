import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Seeds Firestore with the super-admin account on first app launch.
/// Guards against re-seeding using a `_meta/seeded` document.
///
/// After seeding, the following account is available:
///   superadmin@test.com / super@123  → Super Admin
class DbSeeder {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static const _superAdminEmail = 'superadmin@test.com';
  static const _superAdminPassword = 'super@123';

  static Future<void> seedIfNeeded() async {
    try {
      final meta = await _db.collection('_meta').doc('seeded').get();
      if (meta.exists) {
        // Full seed already ran — only repair the superAdmin doc if missing.
        await reseedSuperAdmin();
        return;
      }
      if (kDebugMode) debugPrint('[DbSeeder] Seeding Firestore...');
      await _seed();
      if (kDebugMode) debugPrint('[DbSeeder] Done.');
    } catch (e) {
      if (kDebugMode) debugPrint('[DbSeeder] Error: $e');
    }
  }

  /// Recreates the superAdmin Firestore document if it was accidentally deleted.
  ///
  /// Safe to call on every launch:
  /// - If the doc already exists → returns immediately without signing in.
  /// - If the doc is missing → signs in as superAdmin to get the Firebase Auth
  ///   UID, writes the document, and stays signed in.
  static Future<void> reseedSuperAdmin() async {
    try {
      final existing = await _db
          .collection('users')
          .where('email', isEqualTo: _superAdminEmail)
          .where('role', isEqualTo: 'superAdmin')
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) return;

      if (kDebugMode) {
        debugPrint('[DbSeeder] SuperAdmin doc missing — recreating...');
      }

      final cred = await _auth.signInWithEmailAndPassword(
        email: _superAdminEmail,
        password: _superAdminPassword,
      );
      final uid = cred.user!.uid;

      await _db.collection('users').doc(uid).set({
        'name': 'Admin System',
        'email': _superAdminEmail,
        'phone': '',
        'role': 'superAdmin',
        'apartmentId': null,
        'unit': 'HQ',
        'avatarInitials': 'SA',
        'isActive': true,
        'joinedAt': Timestamp.fromDate(DateTime(2021, 1, 1)),
      });

      if (kDebugMode) {
        debugPrint('[DbSeeder] SuperAdmin doc recreated — uid: $uid');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[DbSeeder] reseedSuperAdmin error: $e');
    }
  }

  static Future<void> _seed() async {
    await _createSuperAdmin();

    await _db.collection('_meta').doc('seeded').set({
      'timestamp': FieldValue.serverTimestamp(),
      'version': 2,
    });

    // Re-sign in as super admin so the app opens on the SuperAdmin dashboard.
    await _auth.signInWithEmailAndPassword(
      email: _superAdminEmail,
      password: _superAdminPassword,
    );
  }

  static Future<void> _createSuperAdmin() async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: _superAdminEmail,
        password: _superAdminPassword,
      );
      final uid = cred.user!.uid;

      await _db.collection('users').doc(uid).set({
        'name': 'Admin System',
        'email': _superAdminEmail,
        'phone': '',
        'role': 'superAdmin',
        'apartmentId': null,
        'unit': 'HQ',
        'avatarInitials': 'SA',
        'isActive': true,
        'joinedAt': Timestamp.fromDate(DateTime(2021, 1, 1)),
      });

      if (kDebugMode) debugPrint('[DbSeeder] SuperAdmin created — uid: $uid');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        // Auth account already exists — try signing in to get the real UID
        // and ensure the Firestore doc is written for that UID.
        try {
          final cred = await _auth.signInWithEmailAndPassword(
            email: _superAdminEmail,
            password: _superAdminPassword,
          );
          final uid = cred.user!.uid;
          final doc = await _db.collection('users').doc(uid).get();
          if (!doc.exists) {
            await _db.collection('users').doc(uid).set({
              'name': 'Admin System',
              'email': _superAdminEmail,
              'phone': '',
              'role': 'superAdmin',
              'apartmentId': null,
              'unit': 'HQ',
              'avatarInitials': 'SA',
              'isActive': true,
              'joinedAt': Timestamp.fromDate(DateTime(2021, 1, 1)),
            });
            if (kDebugMode) debugPrint('[DbSeeder] SuperAdmin doc written for existing Auth uid: $uid');
          }
        } catch (_) {
          // Could not sign in — wrong password or account issue. Skip.
        }
      } else {
        rethrow;
      }
    }
  }
}
