import 'examination.dart';
import 'examination_information.dart';

abstract interface class ExaminationCatalogRepository {
  Future<List<Examination>> search({required String query, int limit = 20});
  Stream<List<ExaminationCategory>> watchCategories();
  Stream<Examination?> watchExamination(String examinationId);
  Stream<List<ExaminationCycle>> watchCycles(String examinationId);
  Stream<ExaminationInformation?> watchInformation(String cycleId);
  Future<void> requestExamination({required String query, required String userId});
}
