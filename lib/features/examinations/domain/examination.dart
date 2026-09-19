class ExaminationCategory {
  const ExaminationCategory({required this.id, required this.name});

  final String id;
  final String name;
}

class Examination {
  const Examination({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.aliases,
  });

  final String id;
  final String categoryId;
  final String name;
  final Set<String> aliases;
}

class ExaminationCycle {
  const ExaminationCycle({
    required this.id,
    required this.examinationId,
    required this.label,
    this.year,
  });

  final String id;
  final String examinationId;
  final String label;
  final int? year;
}
