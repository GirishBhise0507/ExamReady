import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../examinations/application/examination_providers.dart';
import '../data/firestore_official_source_repository.dart';
import '../domain/official_source.dart';
import '../domain/official_source_repository.dart';

final officialSourceRepositoryProvider =
    Provider<OfficialSourceRepository>((ref) {
  return FirestoreOfficialSourceRepository(
    ref.watch(firestoreProvider),
  );
});

final officialSourcesForCycleProvider =
    StreamProvider.family<List<OfficialSource>, String>(
  (ref, cycleId) {
    return ref
        .watch(officialSourceRepositoryProvider)
        .watchForCycle(cycleId);
  },
);
