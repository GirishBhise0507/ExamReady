import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../notifications/presentation/notification_settings_screen.dart';

import '../application/profile_providers.dart';
import '../domain/student_profile.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({
    required this.onSignOut,
    super.key,
  });

  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(studentProfileProvider);
    final firebaseUser = FirebaseAuth.instance.currentUser;

    return profile.when(
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, stackTrace) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Unable to load your profile.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (studentProfile) {
        final name = studentProfile?.name.trim() ?? '';
        final email = studentProfile?.email.trim().isNotEmpty == true
            ? studentProfile!.email
            : firebaseUser?.email ?? '';

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: CircleAvatar(
                radius: 48,
                child: Text(
                  _initial(name, email),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              name.isEmpty ? 'Your Profile' : name,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (email.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                email,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 32),
            _ProfileTile(
              icon: Icons.location_city_outlined,
              label: 'City',
              value: _displayValue(studentProfile?.city),
            ),
            _ProfileTile(
              icon: Icons.school_outlined,
              label: 'Institution',
              value: _displayValue(studentProfile?.institution),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(
                Icons.notifications_outlined,
              ),
              title: const Text(
                'Notification Settings',
              ),
              subtitle: const Text(
                'Exam updates and reminder preferences',
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) =>
                        const NotificationSettingsScreen(),
                  ),
                );
              },
            ),
            FilledButton.icon(
              onPressed: firebaseUser == null
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => EditProfileScreen(
                            userId: firebaseUser.uid,
                            email: email,
                            currentProfile: studentProfile,
                          ),
                        ),
                      );
                    },
              icon: const Icon(Icons.edit_outlined),
              label: Text(
                studentProfile == null ? 'Create Profile' : 'Edit Profile',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onSignOut,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  String _initial(String name, String email) {
    final source = name.isNotEmpty ? name : email;

    if (source.isEmpty) {
      return '?';
    }

    return source.substring(0, 1).toUpperCase();
  }

  String _displayValue(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Not added';
    }

    return value;
  }
}

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({
    required this.userId,
    required this.email,
    required this.currentProfile,
    super.key,
  });

  final String userId;
  final String email;
  final StudentProfile? currentProfile;

  @override
  ConsumerState<EditProfileScreen> createState() =>
      _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _cityController;
  late final TextEditingController _institutionController;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.currentProfile?.name ?? '',
    );

    _cityController = TextEditingController(
      text: widget.currentProfile?.city ?? '',
    );

    _institutionController = TextEditingController(
      text: widget.currentProfile?.institution ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _institutionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your name.'),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await ref.read(profileRepositoryProvider).saveProfile(
            StudentProfile(
              userId: widget.userId,
              name: name,
              email: widget.email,
              phone: widget.currentProfile?.phone,
              photoUrl: widget.currentProfile?.photoUrl,
              city: _nullableText(_cityController.text),
              institution: _nullableText(
                _institutionController.text,
              ),
              dateOfBirth: widget.currentProfile?.dateOfBirth,
            ),
          );

      if (!mounted) return;

      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to save your profile. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  String? _nullableText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: TextEditingController(text: widget.email),
            enabled: false,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _cityController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'City',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_city_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _institutionController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Institution / College',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.school_outlined),
            ),
          ),
          const SizedBox(height: 24),
            FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              _saving ? 'Saving...' : 'Save Changes',
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value),
    );
  }
}

