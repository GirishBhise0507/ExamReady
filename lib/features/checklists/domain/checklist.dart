enum ChecklistItemStatus { pending, completed, notApplicable }

class ChecklistRequirement {
  const ChecklistRequirement({
    required this.id,
    required this.cycleId,
    required this.label,
    this.conditionKey,
  });

  final String id;
  final String cycleId;
  final String label;
  final String? conditionKey;
}

class StudentChecklistItem {
  const StudentChecklistItem({
    required this.requirementId,
    required this.status,
    this.updatedAt,
  });

  final String requirementId;
  final ChecklistItemStatus status;
  final DateTime? updatedAt;
}
