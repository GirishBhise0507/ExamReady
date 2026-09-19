import 'package:firebase_auth/firebase_auth.dart';

import '../domain/auth_session.dart';
import '../domain/authentication_repository.dart';

class FirebaseAuthenticationRepository
    implements AuthenticationRepository {
  FirebaseAuthenticationRepository(this._firebaseAuth);

  final FirebaseAuth _firebaseAuth;

  @override
  Stream<AuthSession> watchSession() {
    return _firebaseAuth.authStateChanges().map((user) {
      if (user == null) {
        return const AuthSession(
          status: AuthenticationStatus.unauthenticated,
        );
      }

      return AuthSession(
        status: AuthenticationStatus.authenticated,
        userId: user.uid,
      );
    });
  }

  @override
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    await _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> createAccountWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    await _firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> signOut() {
    return _firebaseAuth.signOut();
  }
}
