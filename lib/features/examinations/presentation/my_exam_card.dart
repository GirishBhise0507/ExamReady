import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/application/authentication_providers.dart';
import '../application/examination_providers.dart';
import '../domain/student_examination.dart';
import 'examination_details_screen.dart';

class MyExamCard extends ConsumerWidget {
  const MyExamCard({
    required this.studentExamination,
    super.key,
  });

  final StudentExamination studentExamination;

  Future<void> _removeExam({
    required BuildContext context,
    required WidgetRef ref,
    required String examName,
    required String cycleLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Remove exam?',
          ),
          content: Text(
            'Remove $cycleLabel from My Exams?\n\n'
            'This only removes the exam from your dashboard. '
            'Official examination data will not be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text(
                'Remove',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

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

    try {
      await ref
          .read(studentExaminationRepositoryProvider)
          .removeExamination(
            userId: userId,
            cycleId: studentExamination.cycleId,
          );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$examName removed from My Exams.',
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to remove the exam. Please try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examination = ref.watch(
      examinationProvider(
        studentExamination.examinationId,
      ),
    );

    final cycle = ref.watch(
      examinationCycleProvider(
        (
          examinationId:
              studentExamination.examinationId,
          cycleId:
              studentExamination.cycleId,
        ),
      ),
    );

    final exam =
        examination.valueOrNull;

    final examCycle =
        cycle.valueOrNull;

    final examName =
        exam?.name ??
        studentExamination.examinationId;

    final cycleLabel =
        examCycle?.label ??
        studentExamination.cycleId;

    return Card(
      child: ListTile(
        leading: const Icon(
          Icons.school_rounded,
        ),

        title: examination.when(
          loading: () => const Text(
            'Loading...',
          ),
          error: (_, __) => Text(
            studentExamination.examinationId,
          ),
          data: (value) => Text(
            value?.name ??
                studentExamination.examinationId,
          ),
        ),

        subtitle: cycle.when(
          loading: () => const Text(
            'Loading cycle...',
          ),
          error: (_, __) => Text(
            studentExamination.cycleId,
          ),
          data: (value) => Text(
            value?.label ??
                studentExamination.cycleId,
          ),
        ),

        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<String>(
              tooltip: 'Exam options',
              onSelected: (value) async {
                if (value != 'remove') {
                  return;
                }

                await _removeExam(
                  context: context,
                  ref: ref,
                  examName: examName,
                  cycleLabel: cycleLabel,
                );
              },
              itemBuilder: (context) {
                return const [
                  PopupMenuItem<String>(
                    value: 'remove',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Remove exam',
                        ),
                      ],
                    ),
                  ),
                ];
              },
            ),
            const Icon(
              Icons.chevron_right_rounded,
            ),
          ],
        ),

        onTap: () {
          if (
            exam == null ||
            examCycle == null
          ) {
            return;
          }

          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  ExaminationDetailsScreen(
                examination: exam,
                cycleId: examCycle.id,
                cycleLabel: examCycle.label,
              ),
            ),
          );
        },
      ),
    );
  }
}
