import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {
  AuthRepository(this._firebaseAuth);

  final FirebaseAuth _firebaseAuth;

  User? get currentUser => _firebaseAuth.currentUser;

  Stream<User?> authStateChanges() {
    return _firebaseAuth.authStateChanges();
  }

  Future<User> signInAnonymouslyIfNeeded() async {
    final existingUser = _firebaseAuth.currentUser;
    if (existingUser != null) {
      return existingUser;
    }

    return signInAnonymously();
  }

  Future<User> signInAnonymously() async {
    final existingUser = _firebaseAuth.currentUser;
    if (existingUser != null) {
      return existingUser;
    }

    final credential = await _firebaseAuth.signInAnonymously();
    final user = credential.user;
    if (user == null) {
      throw StateError('Anonymous sign-in did not return a user.');
    }

    return user;
  }

  Future<User> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      throw StateError('Email sign-in did not return a user.');
    }

    return user;
  }

  Future<User> createEmailPasswordAccount({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      throw StateError('Email sign-up did not return a user.');
    }

    return user;
  }

  Future<User> linkAnonymousAccountWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user to upgrade.');
    }

    if (!user.isAnonymous) {
      throw StateError('Current user is already linked to a non-anonymous account.');
    }

    final credential = EmailAuthProvider.credential(
      email: email.trim(),
      password: password,
    );
    final result = await user.linkWithCredential(credential);
    final linkedUser = result.user;
    if (linkedUser == null) {
      throw StateError('Failed to link anonymous account with email/password.');
    }

    return linkedUser;
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _firebaseAuth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() {
    return _firebaseAuth.signOut();
  }
}
