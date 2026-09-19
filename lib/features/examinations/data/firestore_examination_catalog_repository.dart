import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/examination.dart';
import '../domain/examination_catalog_repository.dart';
import '../domain/examination_information.dart';

class FirestoreExaminationCatalogRepository
    implements ExaminationCatalogRepository {
  FirestoreExaminationCatalogRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<List<Examination>> search({
    required String query,
    int limit = 20,
  }) async {
    final normalizedQuery = query.trim().toLowerCase();

    if (normalizedQuery.isEmpty) {
      return const <Examination>[];
    }

    final snapshot = await _firestore.collection('examinations').get();

    return snapshot.docs
        .map(_examinationFromDocument)
        .where((examination) {
          final nameMatches =
              examination.name.toLowerCase().contains(normalizedQuery);

          final aliasMatches = examination.aliases.any(
            (alias) => alias.toLowerCase().contains(normalizedQuery),
          );

          return nameMatches || aliasMatches;
        })
        .take(limit)
        .toList();
  }

  @override
  Stream<List<ExaminationCategory>> watchCategories() {
    return _firestore
        .collection('examinationCategories')
        .orderBy('name')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (document) => ExaminationCategory(
                  id: document.id,
                  name: document.data()['name'] as String,
                ),
              )
              .toList(),
        );
  }

  @override
  Stream<Examination?> watchExamination(String examinationId) {
    return _firestore
        .collection('examinations')
        .doc(examinationId)
        .snapshots()
        .map((document) {
          if (!document.exists) {
            return null;
          }

          return _examinationFromDocument(document);
        });
  }

  @override
  Stream<List<ExaminationCycle>> watchCycles(String examinationId) {
    return _firestore
        .collection('examinationCycles')
        .where('examinationId', isEqualTo: examinationId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (document) {
                  final data = document.data();

                  return ExaminationCycle(
                    id: document.id,
                    examinationId: data['examinationId'] as String,
                    label: data['label'] as String,
                    year: data['year'] as int?,
                  );
                },
              )
              .toList(),
        );
  }

  @override
  Stream<ExaminationInformation?> watchInformation(String cycleId) {
    return _firestore
        .collection('examinationInformation')
        .doc(cycleId)
        .snapshots()
        .map((document) {
          if (!document.exists) {
            return null;
          }

          final data = document.data()!;

          return ExaminationInformation(
            cycleId: cycleId,
            importantDates: _importantDatesFromData(data['importantDates']),
            fees: _feesFromData(data['fees']),
            eligibility: _eligibilityFromData(data['eligibility']),
            documentRequirementIds:
                _stringList(data['documentRequirementIds']),
            examDayInstructionIds:
                _stringList(data['examDayInstructionIds']),
          );
        });
  }

  @override
  Future<void> requestExamination({
    required String query,
    required String userId,
  }) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('examinationRequests')
        .add({
      'query': query.trim(),
      'requestedAt': FieldValue.serverTimestamp(),
    });
  }

  Examination _examinationFromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data()!;

    return Examination(
      id: document.id,
      categoryId: data['categoryId'] as String,
      name: data['name'] as String,
      aliases: _stringList(data['aliases']).toSet(),
    );
  }

  List<ImportantDate> _importantDatesFromData(dynamic value) {
    if (value is! List) {
      return const <ImportantDate>[];
    }

    return value.whereType<Map>().map((item) {
      final data = Map<String, dynamic>.from(item);
      final timestamp = data['value'] as Timestamp;

      return ImportantDate(
        type: ImportantDateType.values.byName(data['type'] as String),
        value: timestamp.toDate(),
        sourceIds: _stringList(data['sourceIds']).toSet(),
        label: data['label'] as String?,
      );
    }).toList();
  }

  List<FeeRequirement> _feesFromData(dynamic value) {
    if (value is! List) {
      return const <FeeRequirement>[];
    }

    return value.whereType<Map>().map((item) {
      final data = Map<String, dynamic>.from(item);

      return FeeRequirement(
        label: data['label'] as String,
        amountInr: data['amountInr'] as int,
        sourceIds: _stringList(data['sourceIds']).toSet(),
        categoryLabel: data['categoryLabel'] as String?,
      );
    }).toList();
  }

  List<EligibilityRequirement> _eligibilityFromData(dynamic value) {
    if (value is! List) {
      return const <EligibilityRequirement>[];
    }

    return value.whereType<Map>().map((item) {
      final data = Map<String, dynamic>.from(item);

      return EligibilityRequirement(
        id: data['id'] as String,
        description: data['description'] as String,
        sourceIds: _stringList(data['sourceIds']).toSet(),
        conditionKey: data['conditionKey'] as String?,
      );
    }).toList();
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) {
      return const <String>[];
    }

    return value.whereType<String>().toList();
  }
}
