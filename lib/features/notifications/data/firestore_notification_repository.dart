import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/notification_preferences.dart';
import '../domain/notification_repository.dart';

class FirestoreNotificationRepository
    implements NotificationRepository {
  FirestoreNotificationRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _document(
    String userId,
  ) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('notifications');
  }

  @override
  Stream<NotificationPreferences> watchPreferences(
    String userId,
  ) {
    return _document(userId).snapshots().map((snapshot) {
      final data = snapshot.data();

      if (data == null) {
        return NotificationPreferences(
          officialUpdatesEnabled: true,
          reminderOffsets: {
            const Duration(days: 7),
            const Duration(days: 1),
          },
        );
      }

      final rawOffsets = data['reminderOffsetsDays'];

      final reminderOffsets = rawOffsets is List
          ? rawOffsets
              .whereType<num>()
              .map(
                (value) => Duration(
                  days: value.toInt(),
                ),
              )
              .toSet()
          : <Duration>{
              const Duration(days: 7),
              const Duration(days: 1),
            };

      return NotificationPreferences(
        officialUpdatesEnabled:
            data['officialUpdatesEnabled'] as bool? ?? true,
        reminderOffsets: reminderOffsets,
      );
    });
  }

  @override
  Future<void> savePreferences(
    String userId,
    NotificationPreferences preferences,
  ) {
    final reminderOffsetsDays = preferences.reminderOffsets
        .map((duration) => duration.inDays)
        .toList()
      ..sort();

    return _document(userId).set({
      'officialUpdatesEnabled':
          preferences.officialUpdatesEnabled,
      'reminderOffsetsDays': reminderOffsetsDays,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
