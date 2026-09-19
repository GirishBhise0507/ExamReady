import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

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
          separatorBuilder: (_, __) =>
              const SizedBox(height: 10),
          itemBuilder: (context, index) {
            return _UpdateCard(
              update: items[index],
            );
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

  bool get _hasOfficialNotice {
    final url = update.noticeUrl;

    if (url == null) {
      return false;
    }

    final scheme = url.scheme.toLowerCase();

    return scheme == 'https' || scheme == 'http';
  }

  Future<void> _openNotice(
    BuildContext context,
  ) async {
    final url = update.noticeUrl;

    if (url == null) {
      return;
    }

    final opened = await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to open the official notice.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final critical =
        update.severity == UpdateSeverity.critical;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  child: Icon(
                    critical
                        ? Icons.priority_high_rounded
                        : Icons.notifications_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    update.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          fontWeight:
                              FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Icon(
                  update.verificationStatus ==
                          VerificationStatus.verified
                      ? Icons.verified_rounded
                      : Icons.info_outline,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${_verificationLabel(update)}'
                    ' • '
                    '${_formatDate(
                      update.publishedAt ??
                          update.detectedAt,
                    )}',
                  ),
                ),
              ],
            ),

            if (update.sourceName != null) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.account_balance_outlined,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Official source: '
                      '${update.sourceName}',
                    ),
                  ),
                ],
              ),
            ],

            if (update.confidence != null) ...[
              const SizedBox(height: 6),
              Text(
                'Verification confidence: '
                '${_confidencePercent(
                  update.confidence!,
                )}%',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall,
              ),
            ],

            if (_hasOfficialNotice) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _openNotice(context),
                  icon: const Icon(
                    Icons.open_in_new_rounded,
                  ),
                  label: const Text(
                    'View Official Notice',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _verificationLabel(
    ExaminationUpdate update,
  ) {
    switch (update.verificationStatus) {
      case VerificationStatus.verified:
        return 'Verified official update';

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

  int _confidencePercent(
    double confidence,
  ) {
    final value =
        confidence.clamp(0.0, 1.0);

    return (value * 100).round();
  }

  String _formatDate(
    DateTime date,
  ) {
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

    return '${date.day} '
        '${months[date.month - 1]} '
        '${date.year}';
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
              color:
                  Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              'No Updates Yet',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Verified updates for your selected '
              'examinations will appear here.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
