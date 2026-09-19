import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/application/authentication_providers.dart';
import '../application/examination_providers.dart';
import '../domain/examination.dart';
import '../domain/student_examination.dart';

class ExaminationCycleScreen extends ConsumerWidget {
  const ExaminationCycleScreen({
    required this.examination,
    super.key,
  });

  final Examination examination;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cycles = ref.watch(
      examinationCyclesProvider(examination.id),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(examination.name),
      ),
      body: cycles.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => const Center(
          child: Text('Unable to load examination cycles.'),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Text('No examination cycles available.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final cycle = items[index];

              return Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.calendar_month_outlined,
                  ),
                  title: Text(cycle.label),
                  trailing: const Icon(
                    Icons.add_circle_outline,
                  ),
                  onTap: () async {
                    final session =
                        ref.read(authSessionProvider).valueOrNull;
                    final userId = session?.userId;

                    if (userId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please sign in again.'),
                        ),
                      );
                      return;
                    }

                    try {
                      await ref
                          .read(studentExaminationRepositoryProvider)
                          .addExamination(
                            userId: userId,
                            examination: StudentExamination(
                              cycleId: cycle.id,
                              examinationId: examination.id,
                              addedAt: DateTime.now(),
                            ),
                          );

                      if (!context.mounted) {
                        return;
                      }

                      Navigator.of(context).popUntil(
                        (route) => route.isFirst,
                      );
                    } catch (_) {
                      if (!context.mounted) {
                        return;
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Unable to add examination. Please try again.',
                          ),
                        ),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}



