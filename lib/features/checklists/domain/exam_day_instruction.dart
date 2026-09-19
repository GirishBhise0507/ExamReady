class ExamDayInstruction {
  const ExamDayInstruction({
    required this.id,
    required this.cycleId,
    required this.description,
    required this.sourceIds,
  });

  final String id;
  final String cycleId;
  final String description;
  final Set<String> sourceIds;
}
