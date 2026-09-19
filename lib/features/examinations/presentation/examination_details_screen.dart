import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../authentication/application/authentication_providers.dart';
import '../../checklists/presentation/checklist_screen.dart';
import '../../sources/application/source_providers.dart';
import '../../sources/domain/official_source.dart';
import '../application/examination_providers.dart';
import '../domain/examination.dart';
import '../domain/examination_information.dart';

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

    Future<void> refreshDetails() async {
      ref.invalidate(
        examinationInformationProvider(cycleId),
      );

      ref.invalidate(
        officialSourcesForCycleProvider(cycleId),
      );

      try {
        await ref.read(
          examinationInformationProvider(cycleId).future,
        );
      } catch (_) {
        // The error state remains visible if reloading fails.
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(examination.name),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: refreshDetails,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      body: information.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'Unable to load examination information.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please check your connection and try again.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: refreshDetails,
                  icon: const Icon(
                    Icons.refresh_rounded,
                  ),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (examInformation) {
          final importantDates =
              examInformation?.importantDates ??
                  const <ImportantDate>[];

          final fees =
              examInformation?.fees ??
                  const <FeeRequirement>[];

          final eligibility =
              examInformation?.eligibility ??
                  const <EligibilityRequirement>[];

          final documentIds =
              examInformation?.documentRequirementIds ??
                  const <String>[];

          final nextDate =
              _nextUpcomingDate(importantDates);

          return ListView(
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
                style:
                    Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),

              _SummaryCard(
                icon: Icons.calendar_month_outlined,
                title: 'Important Dates',
                message: importantDates.isEmpty
                    ? 'Not announced yet. Official dates '
                        'have not been added.'
                    : '${importantDates.length} important '
                        '${importantDates.length == 1 ? 'date' : 'dates'} '
                        'available.',
                detail: nextDate == null
                    ? importantDates.isEmpty
                        ? null
                        : 'Open to review all verified dates.'
                    : 'Next: '
                        '${_cleanText(
                          nextDate.label ??
                              _dateTypeLabel(nextDate.type),
                        )} • '
                        '${_formatDate(nextDate.value)}',
                onTap: importantDates.isEmpty
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                _ImportantDatesScreen(
                              examName:
                                  examination.name,
                              cycleLabel:
                                  cycleLabel,
                              dates:
                                  importantDates,
                            ),
                          ),
                        );
                      },
              ),

              const SizedBox(height: 12),

              _SummaryCard(
                icon: Icons.currency_rupee,
                title: 'Application Fees',
                message: fees.isEmpty
                    ? 'Not announced yet. Verified fee '
                        'information has not been added.'
                    : '${fees.length} verified fee '
                        '${fees.length == 1 ? 'item' : 'items'} '
                        'available.',
                detail: fees.isEmpty
                    ? null
                    : 'Tap to view the complete fee breakdown.',
                onTap: fees.isEmpty
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => _FeesScreen(
                              examName:
                                  examination.name,
                              fees: fees,
                            ),
                          ),
                        );
                      },
              ),

              const SizedBox(height: 12),

              _SummaryCard(
                icon: Icons.check_circle_outline,
                title: 'Eligibility',
                message: eligibility.isEmpty
                    ? 'Not announced yet. Verified eligibility '
                        'information has not been added.'
                    : '${eligibility.length} verified eligibility '
                        '${eligibility.length == 1 ? 'entry' : 'entries'} '
                        'available.',
                detail: eligibility.isEmpty
                    ? null
                    : 'Tap to review the complete eligibility criteria.',
                onTap: eligibility.isEmpty
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                _EligibilityScreen(
                              examName:
                                  examination.name,
                              items:
                                  eligibility,
                            ),
                          ),
                        );
                      },
              ),

              const SizedBox(height: 12),

              _SummaryCard(
                icon: Icons.description_outlined,
                title: 'Documents & Checklist',
                message: documentIds.isEmpty
                    ? 'Not announced yet. Verified document '
                        'requirements have not been added.'
                    : '${documentIds.length} required '
                        '${documentIds.length == 1 ? 'document' : 'documents'} '
                        'available.',
                detail: documentIds.isEmpty
                    ? null
                    : 'Open your checklist to review and track them.',
                onTap: documentIds.isEmpty
                    ? null
                    : () {
                        final session = ref
                            .read(authSessionProvider)
                            .valueOrNull;

                        final userId =
                            session?.userId;

                        if (userId == null) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
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
                            builder: (_) =>
                                ChecklistScreen(
                              userId: userId,
                              cycleId: cycleId,
                              examName:
                                  examination.name,
                            ),
                          ),
                        );
                      },
              ),

              const SizedBox(height: 28),

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
                'ExamReady uses official authority sources '
                'for examination information and updates.',
              ),

              const SizedBox(height: 12),

              sources.when(
                loading: () => const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child:
                          CircularProgressIndicator(),
                    ),
                  ),
                ),
                error: (error, stackTrace) =>
                    const Card(
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
                        padding:
                            EdgeInsets.all(16),
                        child: Text(
                          'No official source has been linked '
                          'to this examination cycle yet.',
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      for (final source
                          in items) ...[
                        _OfficialSourceCard(
                          source: source,
                        ),
                        const SizedBox(
                          height: 8,
                        ),
                      ],
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.message,
    this.detail,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled =
        onTap != null;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(12),
        child: Padding(
          padding:
              const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: Theme.of(context)
                    .colorScheme
                    .primary,
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
                    const SizedBox(
                      height: 6,
                    ),
                    Text(message),
                    if (detail != null) ...[
                      const SizedBox(
                        height: 5,
                      ),
                      Text(
                        detail!,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color:
                                  Theme.of(context)
                                      .colorScheme
                                      .primary,
                              fontWeight:
                                  FontWeight.w500,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              if (enabled) ...[
                const SizedBox(width: 8),
                const Padding(
                  padding:
                      EdgeInsets.only(
                    top: 4,
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ImportantDatesScreen
    extends StatelessWidget {
  const _ImportantDatesScreen({
    required this.examName,
    required this.cycleLabel,
    required this.dates,
  });

  final String examName;
  final String cycleLabel;
  final List<ImportantDate> dates;

  @override
  Widget build(BuildContext context) {
    final sorted =
        [...dates]
          ..sort(
            (a, b) =>
                a.value.compareTo(
              b.value,
            ),
          );

    final today =
        DateUtils.dateOnly(
      DateTime.now(),
    );

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Important Dates'),
      ),
      body: ListView(
        padding:
            const EdgeInsets.all(16),
        children: [
          Text(
            examName,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(
                  fontWeight:
                      FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            cycleLabel,
            style:
                Theme.of(context)
                    .textTheme
                    .titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '${sorted.length} verified '
            '${sorted.length == 1 ? 'date' : 'dates'} '
            'from official sources.',
          ),
          const SizedBox(height: 20),

          for (final date in sorted) ...[
            _DateDetailCard(
              date: date,
              isPast:
                  DateUtils.dateOnly(
                    date.value,
                  ).isBefore(today),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _DateDetailCard
    extends StatelessWidget {
  const _DateDetailCard({
    required this.date,
    required this.isPast,
  });

  final ImportantDate date;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    final label =
        _cleanText(
      date.label ??
          _dateTypeLabel(date.type),
    );

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              child: Icon(
                isPast
                    ? Icons.check_rounded
                    : Icons
                        .calendar_today_outlined,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          fontWeight:
                              FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatDate(
                      date.value,
                    ),
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                          fontWeight:
                              FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isPast
                        ? 'Completed'
                        : 'Upcoming',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EligibilityScreen
    extends StatelessWidget {
  const _EligibilityScreen({
    required this.examName,
    required this.items,
  });

  final String examName;
  final List<EligibilityRequirement>
      items;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Eligibility'),
      ),
      body: ListView(
        padding:
            const EdgeInsets.all(16),
        children: [
          Text(
            examName,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(
                  fontWeight:
                      FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '${items.length} verified eligibility '
            '${items.length == 1 ? 'entry' : 'entries'} '
            'from official sources.',
          ),
          const SizedBox(height: 20),

          for (
            var index = 0;
            index < items.length;
            index++
          ) ...[
            _EligibilityCard(
              index: index,
              item: items[index],
            ),
            const SizedBox(
              height: 10,
            ),
          ],
        ],
      ),
    );
  }
}

class _EligibilityCard
    extends StatelessWidget {
  const _EligibilityCard({
    required this.index,
    required this.item,
  });

  final int index;
  final EligibilityRequirement item;

  @override
  Widget build(BuildContext context) {
    final description =
        _cleanText(
      item.description,
    );

    final isGeneral =
        index == 0 &&
        description
            .toLowerCase()
            .startsWith(
              'candidates who',
            );

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons
                      .check_circle_outline,
                  color:
                      Theme.of(context)
                          .colorScheme
                          .primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isGeneral
                        ? 'General eligibility'
                        : 'Eligibility condition '
                            '${index + 1}',
                    style:
                        Theme.of(context)
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
              description,
            ),
          ],
        ),
      ),
    );
  }
}

class _FeesScreen
    extends StatelessWidget {
  const _FeesScreen({
    required this.examName,
    required this.fees,
  });

  final String examName;
  final List<FeeRequirement> fees;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Application Fees'),
      ),
      body: ListView(
        padding:
            const EdgeInsets.all(16),
        children: [
          Text(
            examName,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(
                  fontWeight:
                      FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Verified fee information from official sources.',
          ),
          const SizedBox(height: 20),

          for (final fee in fees) ...[
            Card(
              child: ListTile(
                leading:
                    const CircleAvatar(
                  child: Icon(
                    Icons.currency_rupee,
                  ),
                ),
                title: Text(
                  _cleanText(
                    fee.label,
                  ),
                ),
                subtitle:
                    fee.categoryLabel == null
                        ? null
                        : Text(
                            _cleanText(
                              fee.categoryLabel!,
                            ),
                          ),
                trailing: Text(
                  '₹${fee.amountInr}',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                        fontWeight:
                            FontWeight.bold,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

ImportantDate? _nextUpcomingDate(
  List<ImportantDate> dates,
) {
  if (dates.isEmpty) {
    return null;
  }

  final sorted =
      [...dates]
        ..sort(
          (a, b) =>
              a.value.compareTo(
            b.value,
          ),
        );

  final today =
      DateUtils.dateOnly(
    DateTime.now(),
  );

  for (final date in sorted) {
    final value =
        DateUtils.dateOnly(
      date.value,
    );

    if (!value.isBefore(today)) {
      return date;
    }
  }

  return null;
}

String _dateTypeLabel(
  ImportantDateType type,
) {
  switch (type) {
    case ImportantDateType.applicationStart:
      return 'Application starts';
    case ImportantDateType.applicationDeadline:
      return 'Application deadline';
    case ImportantDateType.correctionWindowStart:
      return 'Correction window opens';
    case ImportantDateType.correctionWindowEnd:
      return 'Correction window closes';
    case ImportantDateType.admitCardRelease:
      return 'Admit card release';
    case ImportantDateType.examination:
      return 'Examination';
    case ImportantDateType.answerKeyRelease:
      return 'Answer key release';
    case ImportantDateType.resultRelease:
      return 'Result release';
    case ImportantDateType.other:
      return 'Important date';
  }
}

String _cleanText(String value) {
  return value
      .replaceAll('â€”', '—')
      .replaceAll('â€“', '–')
      .replaceAll('â€™', '’')
      .replaceAll('â€˜', '‘')
      .replaceAll('â€œ', '“')
      .replaceAll('â€', '”')
      .replaceAll('Â', '')
      .replaceAll(
        RegExp(r'\s+'),
        ' ',
      )
      .trim();
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

class _OfficialSourceCard
    extends StatelessWidget {
  const _OfficialSourceCard({
    required this.source,
  });

  final OfficialSource source;

  bool get _canOpen {
    final scheme =
        source.url.scheme
            .toLowerCase();

    return scheme == 'http' ||
        scheme == 'https';
  }

  Future<void> _openSource(
    BuildContext context,
  ) async {
    if (!_canOpen) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'A valid official source link is not available.',
          ),
        ),
      );

      return;
    }

    final opened =
        await launchUrl(
      source.url,
      mode:
          LaunchMode.externalApplication,
    );

    if (
      !opened &&
      context.mounted
    ) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
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
        source.lastVerifiedAt ??
        source.lastCheckedAt;

    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(16),
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
                  color:
                      Theme.of(context)
                          .colorScheme
                          .primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    source.name,
                    style:
                        Theme.of(context)
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
              'Status: '
              '${_verificationLabel(source.status)}',
            ),

            if (date != null) ...[
              const SizedBox(height: 4),
              Text(
                'Last checked: '
                '${_formatDate(date)}',
              ),
            ],

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child:
                  OutlinedButton.icon(
                onPressed: _canOpen
                    ? () =>
                        _openSource(
                          context,
                        )
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
