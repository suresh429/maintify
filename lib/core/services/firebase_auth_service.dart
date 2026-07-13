import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../models/apartment_model.dart';

/// Wraps all FirebaseAuth operations.
/// Providers call this service; no UI has a direct Firebase dependency.
class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get firebaseUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Sign in ───────────────────────────────────────────────────────────────

  /// Signs in with email/password.
  /// If the Firebase Auth sign-in succeeds but no users doc exists, checks
  /// resident_requests to return a helpful "pending approval" message.
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
        // Check if this user has a pending resident request
        final isPending = await _db
            .collection('resident_requests')
            .where('uid', isEqualTo: cred.user!.uid)
            .where('status', isEqualTo: 'pending')
            .limit(1)
            .get();
        await _auth.signOut();
        if (isPending.docs.isNotEmpty) {
          return (
            user: null,
            error:
                'Your registration is pending approval by the apartment president.',
          );
        }
        return (user: null, error: 'Account data not found. Contact support.');
      }
      return (user: user, error: null);
    } on FirebaseAuthException catch (e) {
      return (user: null, error: _friendlyError(e.code));
    }
  }

  // ── President self-registration ───────────────────────────────────────────

  /// Creates a Firebase Auth account for the apartment president and writes
  /// the users doc and updates the apartment in a single flow.
  Future<({UserModel? user, String? error})> registerPresident({
    required String email,
    required String password,
    required ApartmentModel apt,
    String unit = '',
  }) async {
    try {
      // 1. Create Firebase Auth account
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user!.uid;

      // 2. Compute avatar initials from apt.presidentName
      final name = apt.presidentName ?? email.split('@').first;
      final words = name.trim().split(RegExp(r'\s+'));
      final initials = words
          .where((w) => w.isNotEmpty)
          .take(2)
          .map((w) => w[0].toUpperCase())
          .join();

      // 3. Write users/{uid} doc
      await _db.collection('users').doc(uid).set({
        'name': name,
        'email': email,
        'phone': apt.presidentPhone ?? '',
        'role': 'admin',
        'apartmentId': apt.id,
        'unit': unit,
        'avatarInitials': initials.isEmpty ? name[0].toUpperCase() : initials,
        'isActive': true,
        'joinedAt': Timestamp.fromDate(DateTime.now()),
      });

      // 4. Update apartment: set status='active', presidentId, occupiedFlats +1
      await _db.collection('apartments').doc(apt.id).update({
        'status': 'active',
        'presidentId': uid,
        'presidentName': name,
        'occupiedFlats': FieldValue.increment(1),
      });

      // 5. Return loaded UserModel
      final user = await _loadUserDoc(uid);
      return (user: user, error: null);
    } on FirebaseAuthException catch (e) {
      return (user: null, error: _friendlyError(e.code));
    } catch (_) {
      return (user: null, error: 'An error occurred. Please try again.');
    }
  }

  // ── Resident self-registration ────────────────────────────────────────────

  /// Creates a Firebase Auth account for a resident then immediately signs out.
  /// The caller is responsible for creating the resident_request doc with the
  /// returned UID.
  Future<({String? uid, String? error})> registerResident({
    required String name,
    required String email,
    required String phone,
    required String password,
    required ApartmentModel apt,
    required String unit,
  }) async {
    try {
      // 1. Create Firebase Auth account
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user!.uid;

      // 2. Sign out immediately — no users doc is written yet
      await _auth.signOut();

      return (uid: uid, error: null);
    } on FirebaseAuthException catch (e) {
      return (uid: null, error: _friendlyError(e.code));
    } catch (_) {
      return (uid: null, error: 'An error occurred. Please try again.');
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
