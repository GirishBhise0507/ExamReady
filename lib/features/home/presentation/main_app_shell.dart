import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_destination.dart';
import '../../authentication/application/authentication_providers.dart';
import '../../examinations/presentation/my_exams_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../updates/application/update_providers.dart';
import '../../updates/presentation/updates_view.dart';
import 'home_dashboard.dart';

class MainAppShell extends ConsumerStatefulWidget {
  const MainAppShell({super.key});

  @override
  ConsumerState<MainAppShell> createState() =>
      _MainAppShellState();
}

class _MainAppShellState
    extends ConsumerState<MainAppShell> {
  AppDestination _destination =
      AppDestination.home;

  @override
  Widget build(BuildContext context) {
    final selectedIndex =
        AppDestination.values
            .indexOf(_destination);

    final updateCount =
        ref.watch(
          studentUnreadUpdateCountProvider,
        );

    final updateBadgeText =
        updateCount > 99
            ? '99+'
            : '$updateCount';

    return PopScope(
      canPop: _destination == AppDestination.home,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        if (_destination != AppDestination.home) {
          setState(() {
            _destination = AppDestination.home;
          });
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(
          _titleForDestination(
            _destination,
          ),
        ),
      ),

      body:
          _bodyForDestination(
        _destination,
      ),

      bottomNavigationBar:
          NavigationBar(
        selectedIndex:
            selectedIndex,

        onDestinationSelected:
            (index) {
          setState(() {
            _destination =
                AppDestination
                    .values[index];
          });
        },

        destinations: [
          NavigationDestination(
            icon: Icon(
              Icons.home_outlined,
            ),
            selectedIcon:
                Icon(
              Icons.home,
            ),
            label:
                'Home',
          ),

          NavigationDestination(
            icon: Icon(
              Icons.school_outlined,
            ),
            selectedIcon:
                Icon(
              Icons.school,
            ),
            label:
                'My Exams',
          ),

          NavigationDestination(
            icon: Badge(
              isLabelVisible:
                  updateCount > 0,
              label:
                  Text(
                updateBadgeText,
              ),
              child:
                  const Icon(
                Icons.notifications_outlined,
              ),
            ),
            selectedIcon:
                Badge(
              isLabelVisible:
                  updateCount > 0,
              label:
                  Text(
                updateBadgeText,
              ),
              child:
                  const Icon(
                Icons.notifications,
              ),
            ),
            label:
                'Updates',
          ),

          NavigationDestination(
            icon: Icon(
              Icons.person_outline,
            ),
            selectedIcon:
                Icon(
              Icons.person,
            ),
            label:
                'Profile',
          ),
        ],
      ),
    ),
    );
  }

  Widget _bodyForDestination(
    AppDestination destination,
  ) {
    switch (destination) {
      case AppDestination.home:
        return HomeDashboard(
          onOpenMyExams:
              () {
            setState(() {
              _destination =
                  AppDestination
                      .myExams;
            });
          },
          onOpenUpdates:
              () {
            setState(() {
              _destination =
                  AppDestination
                      .updates;
            });
          },
        );

      case AppDestination.myExams:
        return const MyExamsScreen();

      case AppDestination.updates:
        return const UpdatesScreen();

      case AppDestination.profile:
        return ProfileScreen(
          onSignOut:
              _signOut,
        );
    }
  }

  Future<void> _signOut() async {
    try {
      await ref
          .read(
            authenticationRepositoryProvider,
          )
          .signOut();
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to sign out. '
            'Please try again.',
          ),
        ),
      );
    }
  }

  String _titleForDestination(
    AppDestination destination,
  ) {
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
