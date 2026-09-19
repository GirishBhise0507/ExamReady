import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/application/authentication_providers.dart';
import '../data/firestore_profile_repository.dart';
import '../domain/profile_repository.dart';
import '../domain/student_profile.dart';

final profileFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return FirestoreProfileRepository(
    ref.watch(profileFirestoreProvider),
  );
});

final studentProfileProvider =
    StreamProvider<StudentProfile?>((ref) {
  final session = ref.watch(authSessionProvider).valueOrNull;
  final userId = session?.userId;

  if (userId == null) {
    return Stream.value(null);
  }

  return ref
      .watch(profileRepositoryProvider)
      .watchProfile(userId);
});
