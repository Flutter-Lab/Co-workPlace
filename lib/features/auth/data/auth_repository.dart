import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {
  AuthRepository(this._firebaseAuth);

  final FirebaseAuth _firebaseAuth;

  Stream<User?> authStateChanges() {
    return _firebaseAuth.authStateChanges();
  }

  Future<User> signInAnonymouslyIfNeeded() async {
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

  Future<void> signOut() {
    return _firebaseAuth.signOut();
  }
}
