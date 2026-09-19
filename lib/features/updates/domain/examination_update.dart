import '../../sources/domain/official_source.dart';

enum UpdateSeverity { informational, critical }

class ExaminationUpdate {
  const ExaminationUpdate({
    required this.id,
    required this.cycleId,
    required this.title,
    required this.severity,
    required this.verificationStatus,
    required this.sourceIds,
    required this.detectedAt,
    this.publishedAt,
  });

  final String id;
  final String cycleId;
  final String title;
  final UpdateSeverity severity;
  final VerificationStatus verificationStatus;
  final Set<String> sourceIds;
  final DateTime detectedAt;
  final DateTime? publishedAt;
}
