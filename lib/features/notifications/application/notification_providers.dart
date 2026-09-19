import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/application/authentication_providers.dart';
import '../data/firestore_notification_repository.dart';
import '../domain/notification_preferences.dart';
import '../domain/notification_repository.dart';

final notificationFirestoreProvider =
    Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final notificationRepositoryProvider =
    Provider<NotificationRepository>((ref) {
  return FirestoreNotificationRepository(
    ref.watch(notificationFirestoreProvider),
  );
});

final notificationPreferencesProvider =
    StreamProvider<NotificationPreferences>((ref) {
  final session =
      ref.watch(authSessionProvider).valueOrNull;

  final userId = session?.userId;

  if (userId == null) {
    return Stream.value(
      NotificationPreferences(
        officialUpdatesEnabled: true,
        reminderOffsets: {
          const Duration(days: 7),
          const Duration(days: 1),
        },
      ),
    );
  }

  return ref
      .watch(notificationRepositoryProvider)
      .watchPreferences(userId);
});
