import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sources/domain/official_source.dart';
import '../application/update_providers.dart';
import '../domain/examination_update.dart';

class UpdatesScreen extends ConsumerWidget {
  const UpdatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updates = ref.watch(studentUpdatesProvider);

    return updates.when(
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, stackTrace) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Unable to load examination updates.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const _EmptyUpdates();
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            return _UpdateCard(update: items[index]);
          },
        );
      },
    );
  }
}

class _UpdateCard extends StatelessWidget {
  const _UpdateCard({
    required this.update,
  });

  final ExaminationUpdate update;

  @override
  Widget build(BuildContext context) {
    final critical = update.severity == UpdateSeverity.critical;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            critical
                ? Icons.priority_high_rounded
                : Icons.notifications_outlined,
          ),
        ),
        title: Text(
          update.title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '${_verificationLabel(update)}'
            ' • ${_formatDate(update.publishedAt ?? update.detectedAt)}',
          ),
        ),
      ),
    );
  }

  String _verificationLabel(ExaminationUpdate update) {
    switch (update.verificationStatus) {
      case VerificationStatus.verified:
        return 'Verified';
      case VerificationStatus.pendingVerification:
        return 'Pending verification';
      case VerificationStatus.updateDetected:
        return 'Update detected';
      case VerificationStatus.sourceUnavailable:
        return 'Source unavailable';
      case VerificationStatus.potentiallyOutdated:
        return 'Potentially outdated';
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _EmptyUpdates extends StatelessWidget {
  const _EmptyUpdates();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              'No Updates Yet',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Verified updates for your selected examinations '
              'will appear here.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
