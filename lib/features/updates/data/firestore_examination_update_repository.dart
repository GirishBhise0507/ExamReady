import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../sources/domain/official_source.dart';
import '../domain/examination_update.dart';
import '../domain/examination_update_repository.dart';

class FirestoreExaminationUpdateRepository
    implements ExaminationUpdateRepository {
  FirestoreExaminationUpdateRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<ExaminationUpdate>> watchForStudent(
    String userId,
  ) {
    final controller =
        StreamController<List<ExaminationUpdate>>();

    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
        examinationsSubscription;

    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
        updatesSubscription;

    examinationsSubscription = _firestore
        .collection('users')
        .doc(userId)
        .collection('examinations')
        .snapshots()
        .listen(
      (examinationsSnapshot) {
        final cycleIds = examinationsSnapshot.docs
            .map((document) => document.id)
            .toSet();

        updatesSubscription?.cancel();

        if (cycleIds.isEmpty) {
          controller.add(
            const <ExaminationUpdate>[],
          );
          return;
        }

        updatesSubscription = _firestore
            .collection('examinationUpdates')
            .snapshots()
            .listen(
          (updatesSnapshot) {
            final updates = updatesSnapshot.docs
                .map(_fromDocument)
                .where(
                  (update) =>
                      cycleIds.contains(update.cycleId),
                )
                .toList()
              ..sort(
                (a, b) =>
                    b.detectedAt.compareTo(a.detectedAt),
              );

            controller.add(updates);
          },
          onError: controller.addError,
        );
      },
      onError: controller.addError,
    );

    controller.onCancel = () async {
      await examinationsSubscription?.cancel();
      await updatesSubscription?.cancel();
    };

    return controller.stream;
  }

  ExaminationUpdate _fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    final detectedAt = data['detectedAt'];
    final publishedAt = data['publishedAt'];
    final rawSourceIds = data['sourceIds'];

    return ExaminationUpdate(
      id: document.id,
      cycleId: data['cycleId'] as String? ?? '',
      title: data['title'] as String? ??
          'Official examination update',
      severity: _parseSeverity(
        data['severity'],
      ),
      verificationStatus:
          _parseVerificationStatus(
        data['verificationStatus'],
      ),
      sourceIds: rawSourceIds is List
          ? rawSourceIds.whereType<String>().toSet()
          : const <String>{},
      detectedAt: detectedAt is Timestamp
          ? detectedAt.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
      publishedAt: publishedAt is Timestamp
          ? publishedAt.toDate()
          : null,
      sourceName: _optionalString(
        data['sourceName'],
      ),
      noticeUrl: _parseUri(
        data['noticeUrl'],
      ),
      confidence: _parseDouble(
        data['confidence'],
      ),
    );
  }

  UpdateSeverity _parseSeverity(
    Object? value,
  ) {
    if (value is String) {
      for (final severity in UpdateSeverity.values) {
        if (severity.name == value) {
          return severity;
        }
      }
    }

    return UpdateSeverity.informational;
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

  String? _optionalString(
    Object? value,
  ) {
    if (value is! String) {
      return null;
    }

    final text = value.trim();

    return text.isEmpty ? null : text;
  }

  Uri? _parseUri(
    Object? value,
  ) {
    if (value is! String) {
      return null;
    }

    final text = value.trim();

    if (text.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(text);

    if (uri == null) {
      return null;
    }

    final scheme = uri.scheme.toLowerCase();

    if (scheme != 'https' && scheme != 'http') {
      return null;
    }

    return uri;
  }

  double? _parseDouble(
    Object? value,
  ) {
    if (value is num) {
      return value.toDouble();
    }

    return null;
  }
}
