import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class ExamReadyNotificationService {
  ExamReadyNotificationService._();

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'examready_alerts_v2';

  static const AndroidNotificationChannel channel =
      AndroidNotificationChannel(
    channelId,
    'ExamReady Important Alerts',
    description:
        'Important verified exam updates, deadlines, admit cards and reminders.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static Future<void> initialize() async {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      ),
    );

    await _notifications.initialize(
      settings: initializationSettings,
    );

    final androidPlugin =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.requestNotificationsPermission();

    await androidPlugin?.createNotificationChannel(channel);

    FirebaseMessaging.onMessage.listen(
      (RemoteMessage message) async {
        await showFirebaseMessage(message);
      },
    );
  }

  static Future<void> showFirebaseMessage(
    RemoteMessage message,
  ) async {
    final notification = message.notification;

    final title =
        notification?.title ??
        message.data['title']?.toString() ??
        'ExamReady';

    final body =
        notification?.body ??
        message.data['body']?.toString() ??
        'You have a new ExamReady update.';

    await _notifications.show(
      id: message.messageId?.hashCode ??
          DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          'ExamReady Important Alerts',
          channelDescription:
              'Important verified exam updates, deadlines, admit cards and reminders.',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          category: AndroidNotificationCategory.reminder,
          visibility: NotificationVisibility.public,
        ),
      ),
    );
  }
}
