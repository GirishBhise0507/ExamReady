import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/authentication/presentation/authentication_gate.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';

class ExamReadyApp extends StatefulWidget {
  const ExamReadyApp({super.key});

  @override
  State<ExamReadyApp> createState() => _ExamReadyAppState();
}

class _ExamReadyAppState extends State<ExamReadyApp> {
  static const _onboardingCompletedKey =
      'onboardingCompleted';

  bool? _onboardingCompleted;

  @override
  void initState() {
    super.initState();
    _loadOnboardingState();
  }

  Future<void> _loadOnboardingState() async {
    final preferences =
        await SharedPreferences.getInstance();

    final completed =
        preferences.getBool(
          _onboardingCompletedKey,
        ) ??
        false;

    if (!mounted) {
      return;
    }

    setState(() {
      _onboardingCompleted = completed;
    });
  }

  Future<void> _completeOnboarding() async {
    final preferences =
        await SharedPreferences.getInstance();

    await preferences.setBool(
      _onboardingCompletedKey,
      true,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _onboardingCompleted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ExamReady',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
        ),
        useMaterial3: true,
      ),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    final completed =
        _onboardingCompleted;

    if (completed == null) {
      return const _StartupLoadingScreen();
    }

    if (completed) {
      return const AuthenticationGate();
    }

    return OnboardingScreen(
      onCompleted: _completeOnboarding,
    );
  }
}

class _StartupLoadingScreen
    extends StatelessWidget {
  const _StartupLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
