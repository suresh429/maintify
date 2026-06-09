import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';

/// Wraps all FirebaseAuth operations.
/// Providers call this service; no UI has a direct Firebase dependency.
class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get firebaseUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Sign in ───────────────────────────────────────────────────────────────

  /// Signs in with email/password.
  /// If the account doesn't exist in FirebaseAuth yet but IS in `pending_users`
  /// (admin-created account), promotes it to a real Auth + Firestore user.
  Future<({UserModel? user, String? error})> signIn(
    String email,
    String password,
  ) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      final user = await _loadUserDoc(cred.user!.uid);
      if (user == null) {
        await _auth.signOut();
        return (user: null, error: 'Account data not found. Contact support.');
      }
      return (user: user, error: null);
    } on FirebaseAuthException catch (e) {
      // New user whose Auth account doesn't exist yet (admin created them in Firestore only)
      if (e.code == 'user-not-found' ||
          e.code == 'invalid-credential' ||
          e.code == 'INVALID_LOGIN_CREDENTIALS') {
        return _promotePendingUser(email.trim().toLowerCase(), password);
      }
      return (user: null, error: _friendlyError(e.code));
    }
  }

  /// Handles the first-ever login for an admin-created user:
  /// finds them in `pending_users`, creates their Firebase Auth account,
  /// migrates their Firestore doc, deletes the pending record.
  Future<({UserModel? user, String? error})> _promotePendingUser(
    String email,
    String password,
  ) async {
    try {
      final snap = await _db
          .collection('pending_users')
          .where('email', isEqualTo: email)
          .where('tempPassword', isEqualTo: password)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        return (user: null, error: 'No account found with this email.');
      }

      final pendingData = Map<String, dynamic>.from(snap.docs.first.data());
      final pendingDocId = snap.docs.first.id;

      // Create the real Firebase Auth account
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Write Firestore user doc (drop the temp password)
      pendingData.remove('tempPassword');
      pendingData['isFirstLogin'] = true;
      final realUid = cred.user!.uid;
      await _db.collection('users').doc(realUid).set(pendingData);

      // If this user is an admin, patch the apartment so presidentId
      // becomes the real UID (replacing null or any stale pending_* value).
      final role = pendingData['role'] as String?;
      final aptId = pendingData['apartmentId'] as String?;
      final userName = pendingData['name'] as String?;
      if (role == 'admin' && aptId != null && aptId.isNotEmpty) {
        await _db.collection('apartments').doc(aptId).update({
          'presidentId': realUid,
          'presidentName': userName ?? '',
        });
      }

      // Remove from pending
      await _db.collection('pending_users').doc(pendingDocId).delete();

      final user = await _loadUserDoc(cred.user!.uid);
      return (user: user, error: null);
    } on FirebaseAuthException catch (e) {
      return (user: null, error: _friendlyError(e.code));
    } catch (_) {
      return (user: null, error: 'An error occurred. Please try again.');
    }
  }

  // ── Password management ───────────────────────────────────────────────────

  /// Re-authenticates then updates the password.
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
      await _db
          .collection('users')
          .doc(user.uid)
          .update({'isFirstLogin': false});
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

  /// Sends a Firebase password-reset email.
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

  // ── FCM token ─────────────────────────────────────────────────────────────

  Future<void> saveFcmToken(String uid, String token) async {
    await _db
        .collection('users')
        .doc(uid)
        .update({'fcmToken': token});
  }

  // ── User doc helpers ──────────────────────────────────────────────────────

  Future<UserModel?> _loadUserDoc(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  /// Returns the Firestore UID for the currently signed-in user, or null.
  String? get currentUid => _auth.currentUser?.uid;

  // ── Error messages ────────────────────────────────────────────────────────

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
        return 'Password is too weak.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
