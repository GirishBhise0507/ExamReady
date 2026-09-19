enum ImportantDateType {
  applicationStart,
  applicationDeadline,
  correctionWindowStart,
  correctionWindowEnd,
  admitCardRelease,
  examination,
  answerKeyRelease,
  resultRelease,
  other,
}

class ImportantDate {
  const ImportantDate({
    required this.type,
    required this.value,
    required this.sourceIds,
    this.label,
  });

  final ImportantDateType type;
  final DateTime value;
  final Set<String> sourceIds;
  final String? label;
}

class FeeRequirement {
  const FeeRequirement({
    required this.label,
    required this.amountInr,
    required this.sourceIds,
    this.categoryLabel,
  });

  final String label;
  final int amountInr;
  final Set<String> sourceIds;
  final String? categoryLabel;
}

class EligibilityRequirement {
  const EligibilityRequirement({
    required this.id,
    required this.description,
    required this.sourceIds,
    this.conditionKey,
  });

  final String id;
  final String description;
  final Set<String> sourceIds;
  final String? conditionKey;
}

class ExaminationInformation {
  const ExaminationInformation({
    required this.cycleId,
    required this.importantDates,
    required this.fees,
    required this.eligibility,
    required this.documentRequirementIds,
    required this.examDayInstructionIds,
  });

  final String cycleId;
  final List<ImportantDate> importantDates;
  final List<FeeRequirement> fees;
  final List<EligibilityRequirement> eligibility;
  final List<String> documentRequirementIds;
  final List<String> examDayInstructionIds;
}
