import 'checklist.dart';

abstract interface class ChecklistRepository {
  Stream<List<StudentChecklistItem>> watchChecklist({
    required String userId,
    required String cycleId,
  });

  Future<void> updateItem({
    required String userId,
    required String cycleId,
    required StudentChecklistItem item,
  });
}
