import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/profile_repository.dart';
import '../domain/student_profile.dart';

class FirestoreProfileRepository implements ProfileRepository {
  FirestoreProfileRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<StudentProfile?> watchProfile(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((document) {
      if (!document.exists) {
        return null;
      }

      final data = document.data();

      if (data == null) {
        return null;
      }

      final photoUrl = data['photoUrl'] as String?;
      final dateOfBirth = data['dateOfBirth'];

      return StudentProfile(
        userId: userId,
        name: data['name'] as String? ?? '',
        email: data['email'] as String? ?? '',
        phone: data['phone'] as String?,
        photoUrl: photoUrl == null || photoUrl.isEmpty
            ? null
            : Uri.tryParse(photoUrl),
        city: data['city'] as String?,
        institution: data['institution'] as String?,
        dateOfBirth: dateOfBirth is Timestamp
            ? dateOfBirth.toDate()
            : null,
      );
    });
  }

  @override
  Future<void> saveProfile(StudentProfile profile) {
    return _firestore.collection('users').doc(profile.userId).set(
      {
        'name': profile.name.trim(),
        'email': profile.email.trim(),
        'phone': profile.phone?.trim(),
        'photoUrl': profile.photoUrl?.toString(),
        'city': profile.city?.trim(),
        'institution': profile.institution?.trim(),
        'dateOfBirth': profile.dateOfBirth == null
            ? null
            : Timestamp.fromDate(profile.dateOfBirth!),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
