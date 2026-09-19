import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/student_examination.dart';
import '../domain/student_examination_repository.dart';

class FirestoreStudentExaminationRepository
    implements StudentExaminationRepository {
  FirestoreStudentExaminationRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('examinations');
  }

  @override
  Stream<List<StudentExamination>> watchSelectedExaminations(String userId) {
    return _collection(userId)
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((document) {
            final data = document.data();
            final addedAt = data['addedAt'];

            return StudentExamination(
              cycleId: document.id,
              examinationId: data['examinationId'] as String,
              addedAt: addedAt is Timestamp
                  ? addedAt.toDate()
                  : DateTime.fromMillisecondsSinceEpoch(0),
            );
          }).toList(),
        );
  }

  @override
  Future<void> addExamination({
    required String userId,
    required StudentExamination examination,
  }) {
    return _collection(userId).doc(examination.cycleId).set({
      'examinationId': examination.examinationId,
      'addedAt': Timestamp.fromDate(examination.addedAt),
    });
  }

  @override
  Future<void> removeExamination({
    required String userId,
    required String cycleId,
  }) {
    return _collection(userId).doc(cycleId).delete();
  }
}
