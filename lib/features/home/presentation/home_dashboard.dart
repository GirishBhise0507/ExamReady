import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/application/authentication_providers.dart';
import '../../checklists/application/checklist_providers.dart';
import '../../checklists/domain/checklist.dart';
import '../../examinations/application/examination_providers.dart';
import '../../examinations/domain/examination_information.dart';
import '../../updates/application/update_providers.dart';
import '../../updates/domain/examination_update.dart';

class HomeDashboard extends ConsumerWidget {
  const HomeDashboard({
    required this.onOpenMyExams,
    required this.onOpenUpdates,
    super.key,
  });

  final VoidCallback onOpenMyExams;
  final VoidCallback onOpenUpdates;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected =
        ref.watch(selectedExaminationsProvider);

    final updates =
        ref.watch(studentUpdatesProvider);

    final unreadUpdateCount =
        ref.watch(
          studentUnreadUpdateCountProvider,
        );

    final authSession =
        ref.watch(authSessionProvider).valueOrNull;

    final userId =
        authSession?.userId;

    return selected.when(
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, stackTrace) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Unable to load your examination overview.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (examinations) {
        if (examinations.isEmpty) {
          return _EmptyHome(
            onAddExam: onOpenMyExams,
          );
        }

        _UpcomingExamDate? nextUpcomingDate;

        final examPreviews =
            <_ExamPreview>[];

        var totalChecklistRequirements = 0;
        var completedChecklistRequirements = 0;
        var checklistDataLoading = false;
        var checklistDataError = false;

        for (final selectedExam in examinations) {
          final examAsync = ref.watch(
            examinationProvider(
              selectedExam.examinationId,
            ),
          );

          final cycleAsync = ref.watch(
            examinationCycleProvider(
              (
                examinationId:
                    selectedExam.examinationId,
                cycleId:
                    selectedExam.cycleId,
              ),
            ),
          );

          final informationAsync = ref.watch(
            examinationInformationProvider(
              selectedExam.cycleId,
            ),
          );

          final requirementsAsync = ref.watch(
            checklistRequirementsProvider(
              selectedExam.cycleId,
            ),
          );

          final studentChecklistAsync =
              userId == null
                  ? null
                  : ref.watch(
                      studentChecklistProvider(
                        (
                          userId: userId,
                          cycleId: selectedExam.cycleId,
                        ),
                      ),
                    );

          if (requirementsAsync.hasError ||
              (studentChecklistAsync?.hasError ?? false)) {
            checklistDataError = true;
          }

          final requirements =
              requirementsAsync.valueOrNull;

          final studentItems =
              studentChecklistAsync?.valueOrNull;

          if (requirements == null ||
              (userId != null && studentItems == null)) {
            checklistDataLoading = true;
          } else {
            final currentStudentItems =
                studentItems ??
                const <StudentChecklistItem>[];

            final statusByRequirement = {
              for (final item in currentStudentItems)
                item.requirementId: item.status,
            };

            totalChecklistRequirements +=
                requirements.length;

            completedChecklistRequirements +=
                requirements
                    .where(
                      (requirement) =>
                          statusByRequirement[
                              requirement.id] ==
                          ChecklistItemStatus.completed,
                    )
                    .length;
          }

          final exam =
              examAsync.valueOrNull;

          final cycle =
              cycleAsync.valueOrNull;

          final information =
              informationAsync.valueOrNull;

          final examName =
              exam?.name ??
              selectedExam.examinationId;

          final cycleLabel =
              cycle?.label ??
              selectedExam.cycleId;

          examPreviews.add(
            _ExamPreview(
              examName: examName,
              cycleLabel: cycleLabel,
            ),
          );

          if (information == null) {
            continue;
          }

          final upcoming =
              _nextDate(
            information.importantDates,
          );

          if (upcoming == null) {
            continue;
          }

          final candidate =
              _UpcomingExamDate(
            examName: examName,
            cycleLabel: cycleLabel,
            date: upcoming,
          );

          if (
            nextUpcomingDate == null ||
            candidate.date.value.isBefore(
              nextUpcomingDate.date.value,
            )
          ) {
            nextUpcomingDate =
                candidate;
          }
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(
              selectedExaminationsProvider,
            );

            ref.invalidate(
              studentUpdatesProvider,
            );

            ref.invalidate(
              studentReadUpdateIdsProvider,
            );

            await Future<void>.delayed(
              const Duration(
                milliseconds: 500,
              ),
            );
          },
          child: ListView(
            physics:
                const AlwaysScrollableScrollPhysics(),
            padding:
                const EdgeInsets.all(16),
            children: [
              Text(
                'Your Exam Overview',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(
                      fontWeight:
                          FontWeight.bold,
                    ),
              ),

              const SizedBox(height: 6),

              Text(
                'Important information from your '
                'selected examinations in one place.',
                style:
                    Theme.of(context)
                        .textTheme
                        .bodyMedium,
              ),

              const SizedBox(height: 20),

              _OverviewStats(
                examCount:
                    examinations.length,
                updateCount:
                    unreadUpdateCount,
                hasUpcomingDate:
                    nextUpcomingDate !=
                        null,
              ),

              const SizedBox(height: 20),

              _SectionTitle(
                title: 'Coming Up',
                actionLabel:
                    'My Exams',
                onAction:
                    onOpenMyExams,
              ),

              const SizedBox(height: 10),

              if (nextUpcomingDate != null)
                _UpcomingDateCard(
                  item:
                      nextUpcomingDate,
                  onTap:
                      onOpenMyExams,
                )
              else
                const _EmptySectionCard(
                  icon:
                      Icons
                          .calendar_month_outlined,
                  title:
                      'No upcoming dates yet',
                  message:
                      'Verified upcoming dates will '
                      'appear here when they become '
                      'available.',
                ),

              const SizedBox(height: 24),

              _SectionTitle(
                title:
                    'Latest Update',
                actionLabel:
                    'View all',
                onAction:
                    onOpenUpdates,
              ),

              const SizedBox(height: 10),

              updates.when(
                loading: () =>
                    const Card(
                  child: Padding(
                    padding:
                        EdgeInsets.all(20),
                    child: Center(
                      child:
                          CircularProgressIndicator(),
                    ),
                  ),
                ),
                error:
                    (error, stackTrace) =>
                        const _EmptySectionCard(
                  icon:
                      Icons
                          .notifications_outlined,
                  title:
                      'Updates unavailable',
                  message:
                      'Unable to load official '
                      'updates right now.',
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return const _EmptySectionCard(
                      icon:
                          Icons
                              .notifications_none_rounded,
                      title:
                          'No updates yet',
                      message:
                          'Verified official updates '
                          'for your selected exams '
                          'will appear here.',
                    );
                  }

                  return _LatestUpdateCard(
                    update:
                        items.first,
                    onTap:
                        onOpenUpdates,
                  );
                },
              ),

              const SizedBox(height: 24),

              _SectionTitle(
                title:
                    'My Exams',
                actionLabel:
                    'View all',
                onAction:
                    onOpenMyExams,
              ),

              const SizedBox(height: 10),

              for (
                final exam
                in examPreviews.take(3)
              ) ...[
                _ExamPreviewCard(
                  exam:
                      exam,
                  onTap:
                      onOpenMyExams,
                ),
                const SizedBox(
                  height: 8,
                ),
              ],

              if (examPreviews.length > 3)
                Padding(
                  padding:
                      const EdgeInsets.only(
                    top: 4,
                  ),
                  child: TextButton(
                    onPressed:
                        onOpenMyExams,
                    child: Text(
                      'View all '
                      '${examPreviews.length} exams',
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              _ChecklistProgressCard(
                completed:
                    completedChecklistRequirements,
                total:
                    totalChecklistRequirements,
                isLoading:
                    checklistDataLoading,
                hasError:
                    checklistDataError,
                onTap:
                    onOpenMyExams,
              ),

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

class _OverviewStats extends StatelessWidget {
  const _OverviewStats({
    required this.examCount,
    required this.updateCount,
    required this.hasUpcomingDate,
  });

  final int examCount;
  final int updateCount;
  final bool hasUpcomingDate;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon:
                Icons.school_outlined,
            value:
                '$examCount',
            label:
                examCount == 1
                    ? 'Exam'
                    : 'Exams',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon:
                Icons
                    .notifications_outlined,
            value:
                '$updateCount',
            label:
                updateCount == 1
                    ? 'Unread'
                    : 'Unread',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon:
                Icons
                    .event_available_outlined,
            value:
                hasUpcomingDate
                    ? '1'
                    : '0',
            label:
                'Next date',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 8,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color:
                  Theme.of(context)
                      .colorScheme
                      .primary,
            ),
            const SizedBox(
              height: 6,
            ),
            Text(
              value,
              style:
                  Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        fontWeight:
                            FontWeight.bold,
                      ),
            ),
            Text(
              label,
              textAlign:
                  TextAlign.center,
              style:
                  Theme.of(context)
                      .textTheme
                      .bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style:
                Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                      fontWeight:
                          FontWeight.bold,
                    ),
          ),
        ),
        TextButton(
          onPressed:
              onAction,
          child:
              Text(actionLabel),
        ),
      ],
    );
  }
}

class _UpcomingDateCard
    extends StatelessWidget {
  const _UpcomingDateCard({
    required this.item,
    required this.onTap,
  });

  final _UpcomingExamDate item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final today =
        DateUtils.dateOnly(
      DateTime.now(),
    );

    final date =
        DateUtils.dateOnly(
      item.date.value,
    );

    final days =
        date
            .difference(today)
            .inDays;

    final soon =
        days >= 0 &&
        days <= 14;

    final label =
        _cleanText(
      item.date.label ??
          _dateTypeLabel(
            item.date.type,
          ),
    );

    return Card(
      child: InkWell(
        onTap:
            onTap,
        borderRadius:
            BorderRadius.circular(12),
        child: Padding(
          padding:
              const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    child: Icon(
                      soon
                          ? Icons
                              .priority_high_rounded
                          : Icons
                              .calendar_today_outlined,
                    ),
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          item.examName,
                          style:
                              Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                        ),
                        Text(
                          item.cycleLabel,
                          style:
                              Theme.of(context)
                                  .textTheme
                                  .bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons
                        .chevron_right_rounded,
                  ),
                ],
              ),

              const SizedBox(
                height: 14,
              ),

              Text(
                label,
                style:
                    Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(
                          fontWeight:
                              FontWeight.w600,
                        ),
              ),

              const SizedBox(
                height: 6,
              ),

              Text(
                _formatDate(
                  item.date.value,
                ),
                style:
                    Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                          fontWeight:
                              FontWeight.bold,
                        ),
              ),

              if (days >= 0) ...[
                const SizedBox(
                  height: 6,
                ),
                Text(
                  days == 0
                      ? 'Today'
                      : days == 1
                          ? 'Tomorrow'
                          : '$days days remaining',
                  style:
                      Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                            fontWeight:
                                soon
                                    ? FontWeight
                                        .bold
                                    : null,
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

class _LatestUpdateCard
    extends StatelessWidget {
  const _LatestUpdateCard({
    required this.update,
    required this.onTap,
  });

  final ExaminationUpdate update;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final critical =
        update.severity ==
        UpdateSeverity.critical;

    return Card(
      child: InkWell(
        onTap:
            onTap,
        borderRadius:
            BorderRadius.circular(12),
        child: Padding(
          padding:
              const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                child: Icon(
                  critical
                      ? Icons
                          .priority_high_rounded
                      : Icons
                          .notifications_outlined,
                ),
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      update.title,
                      style:
                          Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                    ),
                    const SizedBox(
                      height: 6,
                    ),
                    Text(
                      update.verificationStatus.name ==
                              'verified'
                          ? 'Verified official update'
                          : 'Official update',
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      _formatDate(
                        update.publishedAt ??
                            update.detectedAt,
                      ),
                      style:
                          Theme.of(context)
                              .textTheme
                              .bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons
                    .chevron_right_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExamPreviewCard
    extends StatelessWidget {
  const _ExamPreviewCard({
    required this.exam,
    required this.onTap,
  });

  final _ExamPreview exam;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap:
            onTap,
        leading:
            const Icon(
          Icons.school_outlined,
        ),
        title:
            Text(
          exam.examName,
        ),
        subtitle:
            Text(
          exam.cycleLabel,
        ),
        trailing:
            const Icon(
          Icons.chevron_right_rounded,
        ),
      ),
    );
  }
}

class _EmptySectionCard
    extends StatelessWidget {
  const _EmptySectionCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              child:
                  Icon(icon),
            ),
            const SizedBox(
              width: 14,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style:
                        Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHome extends StatelessWidget {
  const _EmptyHome({
    required this.onAddExam,
  });

  final VoidCallback onAddExam;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              Icons.school_outlined,
              size: 76,
              color:
                  Theme.of(context)
                      .colorScheme
                      .primary,
            ),
            const SizedBox(
              height: 20,
            ),
            Text(
              'Start with an Exam',
              style:
                  Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(
                        fontWeight:
                            FontWeight.bold,
                      ),
            ),
            const SizedBox(
              height: 8,
            ),
            const Text(
              'Add an examination to see '
              'upcoming dates, official updates '
              'and preparation information here.',
              textAlign:
                  TextAlign.center,
            ),
            const SizedBox(
              height: 20,
            ),
            FilledButton.icon(
              onPressed:
                  onAddExam,
              icon:
                  const Icon(
                Icons.add,
              ),
              label:
                  const Text(
                'Go to My Exams',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChecklistProgressCard extends StatelessWidget {
  const _ChecklistProgressCard({
    required this.completed,
    required this.total,
    required this.isLoading,
    required this.hasError,
    required this.onTap,
  });

  final int completed;
  final int total;
  final bool isLoading;
  final bool hasError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress =
        total == 0
            ? 0.0
            : completed / total;

    final percent =
        (progress * 100).round();

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
              const CircleAvatar(
                child: Icon(
                  Icons.checklist_rounded,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Checklist Progress',
                      style:
                          Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                    ),

                    const SizedBox(height: 6),

                    if (isLoading &&
                        total == 0)
                      const Text(
                        'Loading your checklist progress...',
                      )
                    else if (hasError &&
                        total == 0)
                      const Text(
                        'Checklist progress is temporarily unavailable.',
                      )
                    else if (total == 0)
                      const Text(
                        'No verified checklist requirements '
                        'are available for your selected exams yet.',
                      )
                    else ...[
                      Text(
                        '$completed of $total completed',
                        style:
                            Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                      ),

                      const SizedBox(height: 10),

                      LinearProgressIndicator(
                        value: progress,
                      ),

                      const SizedBox(height: 8),

                      Text(
                        '$percent% complete',
                        style:
                            Theme.of(context)
                                .textTheme
                                .bodySmall,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              const Icon(
                Icons.chevron_right_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class _UpcomingExamDate {
  const _UpcomingExamDate({
    required this.examName,
    required this.cycleLabel,
    required this.date,
  });

  final String examName;
  final String cycleLabel;
  final ImportantDate date;
}

class _ExamPreview {
  const _ExamPreview({
    required this.examName,
    required this.cycleLabel,
  });

  final String examName;
  final String cycleLabel;
}

ImportantDate? _nextDate(
  List<ImportantDate> dates,
) {
  if (dates.isEmpty) {
    return null;
  }

  final today =
      DateUtils.dateOnly(
    DateTime.now(),
  );

  final upcoming =
      dates
          .where(
            (date) =>
                !DateUtils.dateOnly(
                  date.value,
                ).isBefore(today),
          )
          .toList()
        ..sort(
          (a, b) =>
              a.value.compareTo(
            b.value,
          ),
        );

  if (upcoming.isEmpty) {
    return null;
  }

  return upcoming.first;
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

String _cleanText(
  String value,
) {
  return value
      .replaceAll(
        'Ã¢â‚¬â€',
        'â€”',
      )
      .replaceAll(
        'Ã¢â‚¬â€œ',
        'â€“',
      )
      .replaceAll(
        'Ã¢â‚¬â„¢',
        'â€™',
      )
      .replaceAll(
        'Ã‚',
        '',
      )
      .replaceAll(
        RegExp(r'\s+'),
        ' ',
      )
      .trim();
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
