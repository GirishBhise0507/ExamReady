import 'checklist.dart';

abstract interface class ChecklistRequirementRepository {
  Stream<List<ChecklistRequirement>> watchRequirements({
    required String cycleId,
  });
}
