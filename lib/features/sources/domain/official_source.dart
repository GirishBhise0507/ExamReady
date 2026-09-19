enum SourceType { website, notification, bulletin, portal, api, feed, document }

enum VerificationStatus {
  verified,
  pendingVerification,
  updateDetected,
  sourceUnavailable,
  potentiallyOutdated,
}

enum SourceProcessingStatus { notProcessed, processed, needsReview, failed }

class OfficialSource {
  const OfficialSource({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
    required this.status,
    required this.processingStatus,
    this.lastCheckedAt,
    this.lastVerifiedAt,
    this.detectedAt,
    this.confidence,
  });

  final String id;
  final String name;
  final Uri url;
  final SourceType type;
  final VerificationStatus status;
  final SourceProcessingStatus processingStatus;
  final DateTime? lastCheckedAt;
  final DateTime? lastVerifiedAt;
  final DateTime? detectedAt;
  final double? confidence;
}
