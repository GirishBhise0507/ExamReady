import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firestore_checklist_repository.dart';
import '../data/firestore_checklist_requirement_repository.dart';
import '../domain/checklist.dart';
import '../domain/checklist_repository.dart';
import '../domain/checklist_requirement_repository.dart';

final checklistFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final checklistRepositoryProvider = Provider<ChecklistRepository>((ref) {
  return FirestoreChecklistRepository(
    ref.watch(checklistFirestoreProvider),
  );
});

final studentChecklistProvider = StreamProvider.family<
    List<StudentChecklistItem>,
    ({String userId, String cycleId})>((ref, ids) {
  return ref.watch(checklistRepositoryProvider).watchChecklist(
        userId: ids.userId,
        cycleId: ids.cycleId,
      );
});

final checklistRequirementRepositoryProvider =
    Provider<ChecklistRequirementRepository>((ref) {
  return FirestoreChecklistRequirementRepository(
    ref.watch(checklistFirestoreProvider),
  );
});

final checklistRequirementsProvider =
    StreamProvider.family<List<ChecklistRequirement>, String>((ref, cycleId) {
  return ref.watch(checklistRequirementRepositoryProvider).watchRequirements(
        cycleId: cycleId,
      );
});
