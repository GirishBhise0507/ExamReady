import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase_authentication_repository.dart';
import '../domain/auth_session.dart';
import '../domain/authentication_repository.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final authenticationRepositoryProvider =
    Provider<AuthenticationRepository>((ref) {
  return FirebaseAuthenticationRepository(
    ref.watch(firebaseAuthProvider),
  );
});

final authSessionProvider = StreamProvider<AuthSession>((ref) {
  return ref.watch(authenticationRepositoryProvider).watchSession();
});
