import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/application/authentication_providers.dart';
import '../data/firestore_examination_catalog_repository.dart';
import '../data/firestore_student_examination_repository.dart';
import '../domain/examination_catalog_repository.dart';
import '../domain/student_examination.dart';
import '../domain/student_examination_repository.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final examinationCatalogRepositoryProvider =
    Provider<ExaminationCatalogRepository>((ref) {
  return FirestoreExaminationCatalogRepository(
    ref.watch(firestoreProvider),
  );
});
final studentExaminationRepositoryProvider =
    Provider<StudentExaminationRepository>((ref) {
  return FirestoreStudentExaminationRepository(
    ref.watch(firestoreProvider),
  );
});

final selectedExaminationsProvider =
    StreamProvider<List<StudentExamination>>((ref) {
  final authSession = ref.watch(authSessionProvider).valueOrNull;

  if (authSession?.userId == null) {
    return Stream.value(const <StudentExamination>[]);
  }

  return ref
      .watch(studentExaminationRepositoryProvider)
      .watchSelectedExaminations(authSession!.userId!);
});


final examinationCyclesProvider = StreamProvider.family(
  (ref, String examinationId) {
    return ref
        .watch(examinationCatalogRepositoryProvider)
        .watchCycles(examinationId);
  },
);

final examinationProvider = StreamProvider.family(
  (ref, String examinationId) {
    return ref
        .watch(examinationCatalogRepositoryProvider)
        .watchExamination(examinationId);
  },
);

final examinationCycleProvider = StreamProvider.family(
  (ref, ({String examinationId, String cycleId}) ids) {
    return ref
        .watch(examinationCatalogRepositoryProvider)
        .watchCycles(ids.examinationId)
        .map(
          (cycles) => cycles
              .where((cycle) => cycle.id == ids.cycleId)
              .firstOrNull,
        );
  },
);

final examinationInformationProvider = StreamProvider.family(
  (ref, String cycleId) {
    return ref
        .watch(examinationCatalogRepositoryProvider)
        .watchInformation(cycleId);
  },
);
