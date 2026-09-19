import 'student_examination.dart';

abstract interface class StudentExaminationRepository {
  Stream<List<StudentExamination>> watchSelectedExaminations(String userId);

  Future<void> addExamination({
    required String userId,
    required StudentExamination examination,
  });

  Future<void> removeExamination({
    required String userId,
    required String cycleId,
  });
}
