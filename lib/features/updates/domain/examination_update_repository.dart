import 'examination_update.dart';

abstract interface class ExaminationUpdateRepository {
  Stream<List<ExaminationUpdate>> watchForStudent(String userId);

  Future<void> dismissUpdate({
    required String userId,
    required String updateId,
  });

  Future<void> markUpdateRead({
    required String userId,
    required String updateId,
  });
}
