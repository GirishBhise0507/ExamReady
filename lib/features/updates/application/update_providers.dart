import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/application/authentication_providers.dart';
import '../data/firestore_examination_update_repository.dart';
import '../domain/examination_update.dart';
import '../domain/examination_update_repository.dart';

final updatesFirestoreProvider =
    Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final examinationUpdateRepositoryProvider =
    Provider<ExaminationUpdateRepository>((ref) {
  return FirestoreExaminationUpdateRepository(
    ref.watch(updatesFirestoreProvider),
  );
});

final studentUpdatesProvider =
    StreamProvider<List<ExaminationUpdate>>((ref) {
  final session =
      ref.watch(authSessionProvider).valueOrNull;

  final userId =
      session?.userId;

  if (userId == null) {
    return Stream.value(
      const <ExaminationUpdate>[],
    );
  }

  return ref
      .watch(examinationUpdateRepositoryProvider)
      .watchForStudent(userId);
});

final studentReadUpdateIdsProvider =
    StreamProvider<Set<String>>((ref) {
  final session =
      ref.watch(authSessionProvider).valueOrNull;

  final userId =
      session?.userId;

  if (userId == null) {
    return Stream.value(
      const <String>{},
    );
  }

  return ref
      .watch(updatesFirestoreProvider)
      .collection('users')
      .doc(userId)
      .collection('readUpdates')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map(
              (document) => document.id,
            )
            .toSet(),
      );
});

final studentUnreadUpdateCountProvider =
    Provider<int>((ref) {
  final updates =
      ref.watch(studentUpdatesProvider).valueOrNull ??
      const <ExaminationUpdate>[];

  final readIds =
      ref.watch(studentReadUpdateIdsProvider).valueOrNull ??
      const <String>{};

  return updates
      .where(
        (update) => !readIds.contains(update.id),
      )
      .length;
});
