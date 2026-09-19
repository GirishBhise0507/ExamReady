import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/exam_ready_app.dart';
import 'firebase_options.dart';
import 'features/notifications/application/examready_notification_service.dart';
import 'features/notifications/presentation/messaging_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await ExamReadyNotificationService.initialize();

  runApp(
    const ProviderScope(
      child: MessagingBootstrap(
        child: ExamReadyApp(),
      ),
    ),
  );
}
