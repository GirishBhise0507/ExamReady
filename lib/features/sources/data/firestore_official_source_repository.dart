import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/official_source.dart';
import '../domain/official_source_repository.dart';

class FirestoreOfficialSourceRepository
    implements OfficialSourceRepository {
  FirestoreOfficialSourceRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<OfficialSource>> watchForCycle(String cycleId) {
    return _firestore
        .collection('officialSources')
        .where('cycleIds', arrayContains: cycleId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(_fromDocument)
              .toList()
            ..sort(
              (a, b) => a.name.compareTo(b.name),
            ),
        );
  }

  OfficialSource _fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    return OfficialSource(
      id: document.id,
      name: data['name'] as String? ?? document.id,
      url: _parseUri(data['url']),
      type: _parseSourceType(data['type']),
      status: _parseVerificationStatus(data['status']),
      processingStatus:
          _parseProcessingStatus(data['processingStatus']),
      lastCheckedAt: _parseDate(data['lastCheckedAt']),
      lastVerifiedAt: _parseDate(data['lastVerifiedAt']),
      detectedAt: _parseDate(data['detectedAt']),
      confidence: _parseDouble(data['confidence']),
    );
  }

  Uri _parseUri(Object? value) {
    final text = value is String ? value.trim() : '';

    return Uri.tryParse(text) ?? Uri();
  }

  SourceType _parseSourceType(Object? value) {
    if (value is String) {
      for (final type in SourceType.values) {
        if (type.name == value) {
          return type;
        }
      }
    }

    return SourceType.website;
  }

  VerificationStatus _parseVerificationStatus(
    Object? value,
  ) {
    if (value is String) {
      for (final status in VerificationStatus.values) {
        if (status.name == value) {
          return status;
        }
      }
    }

    return VerificationStatus.pendingVerification;
  }

  SourceProcessingStatus _parseProcessingStatus(
    Object? value,
  ) {
    if (value is String) {
      for (final status
          in SourceProcessingStatus.values) {
        if (status.name == value) {
          return status;
        }
      }
    }

    return SourceProcessingStatus.notProcessed;
  }

  DateTime? _parseDate(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    return null;
  }

  double? _parseDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }

    return null;
  }
}
