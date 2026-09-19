import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/checklist.dart';
import '../domain/checklist_repository.dart';

class FirestoreChecklistRepository implements ChecklistRepository {
  FirestoreChecklistRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection({
    required String userId,
    required String cycleId,
  }) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('examinations')
        .doc(cycleId)
        .collection('checklist');
  }

  @override
  Stream<List<StudentChecklistItem>> watchChecklist({
    required String userId,
    required String cycleId,
  }) {
    return _collection(
      userId: userId,
      cycleId: cycleId,
    ).snapshots().map(
      (snapshot) {
        return snapshot.docs.map((document) {
          final data = document.data();
          final updatedAt = data['updatedAt'];

          return StudentChecklistItem(
            requirementId: document.id,
            status: ChecklistItemStatus.values.byName(
              data['status'] as String,
            ),
            updatedAt: updatedAt is Timestamp
                ? updatedAt.toDate()
                : null,
          );
        }).toList();
      },
    );
  }

  @override
  Future<void> updateItem({
    required String userId,
    required String cycleId,
    required StudentChecklistItem item,
  }) {
    return _collection(
      userId: userId,
      cycleId: cycleId,
    ).doc(item.requirementId).set({
      'status': item.status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
