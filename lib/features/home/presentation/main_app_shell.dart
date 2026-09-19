import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_destination.dart';
import '../../authentication/application/authentication_providers.dart';
import '../../examinations/presentation/my_exams_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../updates/presentation/updates_view.dart';

class MainAppShell extends ConsumerStatefulWidget {
  const MainAppShell({super.key});

  @override
  ConsumerState<MainAppShell> createState() => _MainAppShellState();
}

class _MainAppShellState extends ConsumerState<MainAppShell> {
  AppDestination _destination = AppDestination.home;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = AppDestination.values.indexOf(_destination);

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleForDestination(_destination)),
      ),
      body: _bodyForDestination(_destination),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _destination = AppDestination.values[index];
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: 'My Exams',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Updates',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _bodyForDestination(AppDestination destination) {
    switch (destination) {
      case AppDestination.home:
        return const _PlaceholderPage(
          icon: Icons.home_rounded,
          title: 'Home',
          message: 'Your examination overview will appear here.',
        );

      case AppDestination.myExams:
        return const MyExamsScreen();

      case AppDestination.updates:
      return const UpdatesScreen();

      case AppDestination.profile:
        return ProfileScreen(
        onSignOut: _signOut,
      );
    }
  }

  Future<void> _signOut() async {
    try {
      await ref.read(authenticationRepositoryProvider).signOut();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to sign out. Please try again.'),
        ),
      );
    }
  }

  String _titleForDestination(AppDestination destination) {
    switch (destination) {
      case AppDestination.home:
        return 'ExamReady';
      case AppDestination.myExams:
        return 'My Exams';
      case AppDestination.updates:
        return 'Updates';
      case AppDestination.profile:
        return 'Profile';
    }
  }
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}












