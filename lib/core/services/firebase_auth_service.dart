import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../models/apartment_model.dart';

/// Wraps all FirebaseAuth operations.
/// Providers call this service; no UI has a direct Firebase dependency.
class FirebaseAuthService {
  final FirebaseAuth      _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db   = FirebaseFirestore.instance;

  User? get firebaseUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Sign in ───────────────────────────────────────────────────────────────

  /// Signs in with email/password.
  /// Returns error: 'EMAIL_NOT_VERIFIED' if the account exists but email
  /// hasn't been verified yet — the caller shows a resend-verification prompt.
  Future<({UserModel? user, String? error})> signIn(
    String email,
    String password,
  ) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      // Block unverified accounts
      if (!cred.user!.emailVerified) {
        await _auth.signOut();
        return (user: null, error: 'EMAIL_NOT_VERIFIED');
      }

      final user = await _loadUserDoc(cred.user!.uid);
      if (user == null) {
        await _auth.signOut();
        return (user: null, error: 'Account data not found. Contact support.');
      }
      return (user: user, error: null);
    } on FirebaseAuthException catch (e) {
      return (user: null, error: _friendlyError(e.code));
    }
  }

  // ── President activation (Secondary flow) ────────────────────────────────

  /// Creates a Firebase Auth account for the president, writes the users doc,
  /// and updates the apartment atomically via WriteBatch.
  /// Rolls back the Auth account if Firestore fails.
  Future<({UserModel? user, String? error})> registerPresident({
    required String email,
    required String password,
    required ApartmentModel apt,
    required String unit,
  }) async {
    User? createdUser;
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      createdUser = cred.user;
      final uid = createdUser!.uid;

      // Send verification email (in background — don't block activation)
      createdUser.sendEmailVerification().catchError((_) {});

      final name     = apt.presidentName ?? email.split('@').first;
      final words    = name.trim().split(RegExp(r'\s+'));
      final initials = words
          .where((w) => w.isNotEmpty)
          .take(2)
          .map((w) => w[0].toUpperCase())
          .join();
      final now = DateTime.now();

      // Atomic batch: create users doc + activate apartment
      final batch = _db.batch();
      batch.set(_db.collection('users').doc(uid), {
        'name':            name,
        'email':           email,
        'phone':           apt.presidentPhone ?? '',
        'role':            'admin',
        'apartmentId':     apt.id,
        'unit':            unit,
        'avatarInitials':  initials.isEmpty ? name[0].toUpperCase() : initials,
        'isActive':        true,
        'joinedAt':        Timestamp.fromDate(now),
      });
      batch.update(_db.collection('apartments').doc(apt.id), {
        'status':         'active',
        'presidentId':    uid,
        'presidentName':  name,
        'occupiedFlats':  FieldValue.increment(1),
        'updatedAt':      Timestamp.fromDate(now),
      });
      await batch.commit();

      final user = await _loadUserDoc(uid);
      return (user: user, error: null);
    } on FirebaseAuthException catch (e) {
      return (user: null, error: _friendlyError(e.code));
    } catch (_) {
      // Rollback: delete Auth account so it doesn't become an orphan
      await createdUser?.delete().catchError((_) {});
      return (user: null, error: 'Registration failed. Please try again.');
    }
  }

  // ── President self-registration (Primary flow) ────────────────────────────

  /// Creates Auth account, apartment doc, and president users doc atomically.
  /// Rolls back Auth account if Firestore batch fails.
  Future<({UserModel? user, String? error})> selfRegisterPresident({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String apartmentId,
    required String apartmentCode,
    required String apartmentName,
    required String apartmentType,
    required String address,
    required int    totalFlats,
    required int    towerCount,
    required List<String> towerNames,
    required String presidentFlat,
  }) async {
    User? createdUser;
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      createdUser = cred.user;
      final uid = createdUser!.uid;

      // Send verification email in background
      createdUser.sendEmailVerification().catchError((_) {});

      final words    = name.trim().split(RegExp(r'\s+'));
      final initials = words
          .where((w) => w.isNotEmpty)
          .take(2)
          .map((w) => w[0].toUpperCase())
          .join();
      final now = DateTime.now();

      // Atomic batch: apartment + user doc
      final batch = _db.batch();
      batch.set(_db.collection('apartments').doc(apartmentId), {
        'name':           apartmentName,
        'code':           apartmentCode,
        'status':         'active',
        'type':           apartmentType,
        'address':        address,
        'totalFlats':     totalFlats,
        'towerCount':     towerCount,
        'towerNames':     towerNames,
        'presidentId':    uid,
        'presidentName':  name,
        'presidentEmail': email,
        'presidentPhone': phone,
        'presidentFlat':  presidentFlat,
        'occupiedFlats':  1,
        'createdAt':      Timestamp.fromDate(now),
        'updatedAt':      Timestamp.fromDate(now),
      });
      batch.set(_db.collection('users').doc(uid), {
        'name':           name,
        'email':          email,
        'phone':          phone,
        'role':           'admin',
        'apartmentId':    apartmentId,
        'unit':           presidentFlat,
        'avatarInitials': initials.isEmpty ? name[0].toUpperCase() : initials,
        'isActive':       true,
        'joinedAt':       Timestamp.fromDate(now),
      });
      await batch.commit();

      final user = await _loadUserDoc(uid);
      return (user: user, error: null);
    } on FirebaseAuthException catch (e) {
      return (user: null, error: _friendlyError(e.code));
    } catch (_) {
      await createdUser?.delete().catchError((_) {});
      return (user: null, error: 'Registration failed. Please try again.');
    }
  }

  // ── Resident direct registration ──────────────────────────────────────────

  /// Creates a resident Firebase Auth account, users doc, and reserves the flat
  /// atomically. Sends a verification email immediately.
  /// Signs out after creating — login requires email verification.
  /// Rolls back the Auth account if Firestore batch fails.
  Future<({UserModel? user, String? error})> registerResident({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String apartmentId,
    required String flatId,
    required String flatNumber,
  }) async {
    User? createdUser;
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      createdUser = cred.user;
      final uid = createdUser!.uid;

      // Send email verification before anything else
      await createdUser.sendEmailVerification();

      final words    = name.trim().split(RegExp(r'\s+'));
      final initials = words
          .where((w) => w.isNotEmpty)
          .take(2)
          .map((w) => w[0].toUpperCase())
          .join();
      final now = DateTime.now();

      // Atomic batch: create users doc + reserve flat + increment occupiedFlats
      final batch = _db.batch();
      batch.set(_db.collection('users').doc(uid), {
        'name':           name,
        'email':          email,
        'phone':          phone,
        'role':           'user',
        'apartmentId':    apartmentId,
        'unit':           flatNumber,
        'avatarInitials': initials.isEmpty ? name[0].toUpperCase() : initials,
        'isActive':       true,
        'joinedAt':       Timestamp.fromDate(now),
      });
      batch.update(_db.collection('flats').doc(flatId), {
        'status':       'occupied',
        'residentId':   uid,
        'residentType': 'Resident',
        'updatedAt':    Timestamp.fromDate(now),
      });
      batch.update(_db.collection('apartments').doc(apartmentId), {
        'occupiedFlats': FieldValue.increment(1),
        'updatedAt':     Timestamp.fromDate(now),
      });
      await batch.commit();

      final user = await _loadUserDoc(uid);
      return (user: user, error: null);
    } on FirebaseAuthException catch (e) {
      return (user: null, error: _friendlyError(e.code));
    } catch (_) {
      await createdUser?.delete().catchError((_) {});
      return (user: null, error: 'Registration failed. Please try again.');
    }
  }

  // ── Email verification ────────────────────────────────────────────────────

  /// Temporarily signs in to resend a verification email, then signs out.
  Future<bool> resendEmailVerification(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      if (cred.user != null && !cred.user!.emailVerified) {
        await cred.user!.sendEmailVerification();
      }
      await _auth.signOut();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Password management ───────────────────────────────────────────────────

  Future<({bool ok, String? error})> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return (ok: false, error: 'Not signed in.');
    try {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);
      return (ok: true, error: null);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' ||
          e.code == 'invalid-credential' ||
          e.code == 'INVALID_LOGIN_CREDENTIALS') {
        return (ok: false, error: 'Current password is incorrect.');
      }
      return (ok: false, error: _friendlyError(e.code));
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(
          email: email.trim().toLowerCase());
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Sign out ──────────────────────────────────────────────────────────────

  Future<void> signOut() => _auth.signOut();

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<UserModel?> _loadUserDoc(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  String? get currentUid => _auth.currentUser?.uid;

  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found':
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'email-already-in-use':
        return 'Email is already registered.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
