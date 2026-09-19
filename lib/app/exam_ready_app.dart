import 'package:flutter/material.dart';

import '../features/onboarding/presentation/onboarding_screen.dart';

class ExamReadyApp extends StatelessWidget {
  const ExamReadyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ExamReady',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const OnboardingScreen(),
    );
  }
}
