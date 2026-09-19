import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/examination_providers.dart';
import '../domain/student_examination.dart';
import 'examination_details_screen.dart';

class MyExamCard extends ConsumerWidget {
  const MyExamCard({
    required this.studentExamination,
    super.key,
  });

  final StudentExamination studentExamination;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examination = ref.watch(
      examinationProvider(studentExamination.examinationId),
    );

    final cycle = ref.watch(
      examinationCycleProvider(
        (
          examinationId: studentExamination.examinationId,
          cycleId: studentExamination.cycleId,
        ),
      ),
    );

    return Card(
      child: ListTile(
        leading: const Icon(Icons.school_rounded),
        title: examination.when(
          loading: () => const Text('Loading...'),
          error: (_, __) => Text(studentExamination.examinationId),
          data: (exam) => Text(
            exam?.name ?? studentExamination.examinationId,
          ),
        ),
        subtitle: cycle.when(
          loading: () => const Text('Loading cycle...'),
          error: (_, __) => Text(studentExamination.cycleId),
          data: (examCycle) => Text(
            examCycle?.label ?? studentExamination.cycleId,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          final exam = examination.valueOrNull;
          final examCycle = cycle.valueOrNull;

          if (exam == null || examCycle == null) {
            return;
          }

          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ExaminationDetailsScreen(
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



