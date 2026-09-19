import 'student_profile.dart';

abstract interface class ProfileRepository {
  Stream<StudentProfile?> watchProfile(String userId);
  Future<void> saveProfile(StudentProfile profile);
}
