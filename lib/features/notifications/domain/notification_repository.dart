import 'notification_preferences.dart';

/// Sends only published changes; source polling alone must never notify students.
abstract interface class NotificationRepository {
  Stream<NotificationPreferences> watchPreferences(String userId);
  Future<void> savePreferences(String userId, NotificationPreferences preferences);
}
