import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../authentication/application/authentication_providers.dart';
import '../../checklists/presentation/checklist_screen.dart';
import '../../sources/application/source_providers.dart';
import '../../sources/domain/official_source.dart';
import '../application/examination_providers.dart';
import '../domain/examination.dart';

class ExaminationDetailsScreen extends ConsumerWidget {
  const ExaminationDetailsScreen({
    required this.examination,
    required this.cycleId,
    required this.cycleLabel,
    super.key,
  });

  final Examination examination;
  final String cycleId;
  final String cycleLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final information =
        ref.watch(examinationInformationProvider(cycleId));

    final sources =
        ref.watch(officialSourcesForCycleProvider(cycleId));

    return Scaffold(
      appBar: AppBar(
        title: Text(examination.name),
      ),
      body: information.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => const Center(
          child: Text(
            'Unable to load examination information.',
          ),
        ),
        data: (examInformation) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              examination.name,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              cycleLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),

            _InformationCard(
              icon: Icons.calendar_month_outlined,
              title: 'Important Dates',
              message: examInformation == null ||
                      examInformation.importantDates.isEmpty
                  ? 'Not announced yet. Official dates have not been added.'
                  : examInformation.importantDates
                      .map(
                        (date) =>
                            '${date.label ?? date.type.name}: '
                            '${_formatDate(date.value)}',
                      )
                      .join('\n'),
            ),

            const SizedBox(height: 12),

            _InformationCard(
              icon: Icons.currency_rupee,
              title: 'Application Fees',
              message: examInformation == null ||
                      examInformation.fees.isEmpty
                  ? 'Not announced yet. Verified fee information has not been added.'
                  : examInformation.fees
                      .map(
                        (fee) =>
                            '${fee.label}: Rs. ${fee.amountInr}',
                      )
                      .join('\n'),
            ),

            const SizedBox(height: 12),

            _InformationCard(
              icon: Icons.check_circle_outline,
              title: 'Eligibility',
              message: examInformation == null ||
                      examInformation.eligibility.isEmpty
                  ? 'Not announced yet. Verified eligibility information has not been added.'
                  : examInformation.eligibility
                      .map((item) => item.description)
                      .join('\n'),
            ),

            const SizedBox(height: 12),

            _InformationCard(
              icon: Icons.description_outlined,
              title: 'Documents & Checklist',
              message: examInformation == null ||
                      examInformation
                          .documentRequirementIds.isEmpty
                  ? 'Not announced yet. Verified document requirements have not been added.'
                  : 'Document checklist is available.',
              onTap: () {
                final session =
                    ref.read(authSessionProvider).valueOrNull;

                final userId = session?.userId;

                if (userId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please sign in again.',
                      ),
                    ),
                  );
                  return;
                }

                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ChecklistScreen(
                      userId: userId,
                      cycleId: cycleId,
                      examName: examination.name,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            Text(
              'Official Sources',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),

            const SizedBox(height: 8),

            const Text(
              'ExamReady uses official authority sources for '
              'examination information and updates.',
            ),

            const SizedBox(height: 12),

            sources.when(
              loading: () => const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
              error: (error, stackTrace) => const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Unable to load official sources.',
                  ),
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No official source has been linked '
                        'to this examination cycle yet.',
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    for (final source in items) ...[
                      _OfficialSourceCard(
                        source: source,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                );
              },
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
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

  return '${date.day} '
      '${months[date.month - 1]} '
      '${date.year}';
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({
    required this.icon,
    required this.title,
    required this.message,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color:
                    Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight:
                                FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(message),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfficialSourceCard extends StatelessWidget {
  const _OfficialSourceCard({
    required this.source,
  });

  final OfficialSource source;

  bool get _canOpen {
    final scheme = source.url.scheme.toLowerCase();

    return scheme == 'http' || scheme == 'https';
  }

  Future<void> _openSource(
    BuildContext context,
  ) async {
    if (!_canOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A valid official source link is not available.',
          ),
        ),
      );
      return;
    }

    final opened = await launchUrl(
      source.url,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to open the official source.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final date =
        source.lastVerifiedAt ?? source.lastCheckedAt;

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
                Icon(
                  Icons.verified_outlined,
                  color: Theme.of(context)
                      .colorScheme
                      .primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    source.name,
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

            Text(
              'Status: ${_verificationLabel(source.status)}',
            ),

            if (date != null) ...[
              const SizedBox(height: 4),
              Text(
                'Last checked: ${_formatDate(date)}',
              ),
            ],

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _canOpen
                    ? () => _openSource(context)
                    : null,
                icon: const Icon(
                  Icons.open_in_new_rounded,
                ),
                label: const Text(
                  'View Official Source',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _verificationLabel(
  VerificationStatus status,
) {
  switch (status) {
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
