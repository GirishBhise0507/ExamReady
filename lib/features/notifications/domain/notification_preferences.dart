class NotificationPreferences {
  const NotificationPreferences({
    required this.officialUpdatesEnabled,
    required this.reminderOffsets,
  });

  final bool officialUpdatesEnabled;
  final Set<Duration> reminderOffsets;
}
