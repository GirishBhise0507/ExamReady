import 'package:app_settings/app_settings.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/application/authentication_providers.dart';
import '../application/notification_providers.dart';
import '../domain/notification_preferences.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen>
    with WidgetsBindingObserver {
  AuthorizationStatus? _authorizationStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshNotificationStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshNotificationStatus();
    }
  }

  Future<void> _refreshNotificationStatus() async {
    final settings =
        await FirebaseMessaging.instance.getNotificationSettings();

    if (!mounted) {
      return;
    }

    setState(() {
      _authorizationStatus = settings.authorizationStatus;
    });
  }

  bool get _notificationsAllowed {
    return _authorizationStatus == AuthorizationStatus.authorized ||
        _authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<void> _openNotificationSettings() async {
    await AppSettings.openAppSettings(
      type: AppSettingsType.notification,
    );
  }

  @override
  Widget build(BuildContext context) {
    final preferences =
        ref.watch(notificationPreferencesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: preferences.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Unable to load notification preferences.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (value) => _NotificationSettingsBody(
          preferences: value,
          notificationsAllowed: _notificationsAllowed,
          statusKnown: _authorizationStatus != null,
          onOpenNotificationSettings: _openNotificationSettings,
        ),
      ),
    );
  }
}

class _NotificationSettingsBody extends ConsumerWidget {
  const _NotificationSettingsBody({
    required this.preferences,
    required this.notificationsAllowed,
    required this.statusKnown,
    required this.onOpenNotificationSettings,
  });

  final NotificationPreferences preferences;
  final bool notificationsAllowed;
  final bool statusKnown;
  final VoidCallback onOpenNotificationSettings;

  Future<void> _save(
    WidgetRef ref,
    NotificationPreferences updated,
  ) async {
    final session =
        ref.read(authSessionProvider).valueOrNull;

    final userId = session?.userId;

    if (userId == null) {
      return;
    }

    await ref
        .read(notificationRepositoryProvider)
        .savePreferences(userId, updated);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final has7Days = preferences.reminderOffsets.contains(
      const Duration(days: 7),
    );

    final has1Day = preferences.reminderOffsets.contains(
      const Duration(days: 1),
    );

    final hasSameDay = preferences.reminderOffsets.contains(
      Duration.zero,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Exam Alerts',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose which verified exam changes and reminders '
          'you want ExamReady to prepare for.',
        ),
        const SizedBox(height: 20),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      notificationsAllowed
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_off_outlined,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Notification Health',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (!statusKnown)
                  const Text(
                    'Checking notification permission...',
                  )
                else if (notificationsAllowed)
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Notifications are allowed. ExamReady uses high-priority alerts for important exam updates.',
                        ),
                      ),
                    ],
                  )
                else
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Notifications are disabled. Enable them so you do not miss important exam alerts.',
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'For important deadlines, admit cards and '
                        'exam-date changes, also enable pop-up or '
                        'heads-up notifications in Android settings.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onOpenNotificationSettings,
                    icon: const Icon(
                      Icons.settings_outlined,
                    ),
                    label: const Text(
                      'Open Notification Settings',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        Card(
          child: SwitchListTile(
            secondary: const Icon(
              Icons.verified_outlined,
            ),
            title: const Text(
              'Official exam updates',
            ),
            subtitle: const Text(
              'Receive alerts only after an exam update '
              'has been published and verified.',
            ),
            value:
                preferences.officialUpdatesEnabled,
            onChanged: (enabled) {
              _save(
                ref,
                NotificationPreferences(
                  officialUpdatesEnabled: enabled,
                  reminderOffsets:
                      preferences.reminderOffsets,
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        Card(
          child: Column(
            children: [
              const ListTile(
                leading: Icon(
                  Icons.schedule_outlined,
                ),
                title: Text(
                  'Reminder timing',
                ),
                subtitle: Text(
                  'These reminders apply to supported '
                  'important exam dates.',
                ),
              ),
              const Divider(height: 1),
              CheckboxListTile(
                title: const Text('7 days before'),
                value: has7Days,
                onChanged: (selected) {
                  final updated =
                      Set<Duration>.from(
                    preferences.reminderOffsets,
                  );

                  if (selected ?? false) {
                    updated.add(
                      const Duration(days: 7),
                    );
                  } else {
                    updated.remove(
                      const Duration(days: 7),
                    );
                  }

                  _save(
                    ref,
                    NotificationPreferences(
                      officialUpdatesEnabled:
                          preferences
                              .officialUpdatesEnabled,
                      reminderOffsets: updated,
                    ),
                  );
                },
              ),
              CheckboxListTile(
                title: const Text('1 day before'),
                value: has1Day,
                onChanged: (selected) {
                  final updated =
                      Set<Duration>.from(
                    preferences.reminderOffsets,
                  );

                  if (selected ?? false) {
                    updated.add(
                      const Duration(days: 1),
                    );
                  } else {
                    updated.remove(
                      const Duration(days: 1),
                    );
                  }

                  _save(
                    ref,
                    NotificationPreferences(
                      officialUpdatesEnabled:
                          preferences
                              .officialUpdatesEnabled,
                      reminderOffsets: updated,
                    ),
                  );
                },
              ),
              CheckboxListTile(
                title: const Text('On the day'),
                value: hasSameDay,
                onChanged: (selected) {
                  final updated =
                      Set<Duration>.from(
                    preferences.reminderOffsets,
                  );

                  if (selected ?? false) {
                    updated.add(Duration.zero);
                  } else {
                    updated.remove(Duration.zero);
                  }

                  _save(
                    ref,
                    NotificationPreferences(
                      officialUpdatesEnabled:
                          preferences
                              .officialUpdatesEnabled,
                      reminderOffsets: updated,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

