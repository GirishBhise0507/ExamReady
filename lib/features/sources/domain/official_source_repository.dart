import 'official_source.dart';

abstract interface class OfficialSourceRepository {
  Stream<List<OfficialSource>> watchForCycle(String cycleId);
}
