import 'examination_update.dart';

abstract interface class ExaminationUpdateRepository {
  Stream<List<ExaminationUpdate>> watchForStudent(String userId);
}
