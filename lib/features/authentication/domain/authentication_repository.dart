import 'auth_session.dart';

/// Contract for application authentication.
///
/// Firebase Authentication provides the concrete implementation.
abstract interface class AuthenticationRepository {
  Stream<AuthSession> watchSession();

  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<void> createAccountWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<void> signOut();
}
