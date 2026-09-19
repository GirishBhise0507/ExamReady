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
  Stream<List<ExaminationUpdate>> watchForStudent(String userId) {
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
          controller.add(const <ExaminationUpdate>[]);
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
                  (update) => cycleIds.contains(update.cycleId),
                )
                .toList()
              ..sort(
                (a, b) => b.detectedAt.compareTo(a.detectedAt),
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
      cycleId: data['cycleId'] as String,
      title: data['title'] as String,
      severity: UpdateSeverity.values.byName(
        data['severity'] as String,
      ),
      verificationStatus: VerificationStatus.values.byName(
        data['verificationStatus'] as String,
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
    );
  }
}
