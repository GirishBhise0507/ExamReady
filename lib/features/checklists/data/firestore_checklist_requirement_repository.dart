import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/checklist.dart';
import '../domain/checklist_requirement_repository.dart';

class FirestoreChecklistRequirementRepository
    implements ChecklistRequirementRepository {
  FirestoreChecklistRequirementRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<ChecklistRequirement>> watchRequirements({
    required String cycleId,
  }) {
    return _firestore
        .collection('checklistRequirements')
        .where('cycleId', isEqualTo: cycleId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((document) {
            final data = document.data();

            return ChecklistRequirement(
              id: document.id,
              cycleId: data['cycleId'] as String,
              label: data['label'] as String,
              conditionKey: data['conditionKey'] as String?,
            );
          }).toList(),
        );
  }
}
