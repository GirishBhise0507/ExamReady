import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/authentication_providers.dart';
import '../domain/auth_session.dart';
import '../../home/presentation/main_app_shell.dart';
import 'authentication_screen.dart';

class AuthenticationGate extends ConsumerWidget {
  const AuthenticationGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authSessionProvider);

    return session.when(
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stackTrace) => const AuthenticationScreen(),
      data: (authSession) {
        switch (authSession.status) {
          case AuthenticationStatus.authenticated:
            return const MainAppShell();

          case AuthenticationStatus.unauthenticated:
          case AuthenticationStatus.unknown:
            return const AuthenticationScreen();
        }
      },
    );
  }
}
