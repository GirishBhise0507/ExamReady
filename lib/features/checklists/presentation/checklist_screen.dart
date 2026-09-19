import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/checklist_providers.dart';
import '../domain/checklist.dart';

class ChecklistScreen extends ConsumerWidget {
  const ChecklistScreen({
    required this.userId,
    required this.cycleId,
    required this.examName,
    super.key,
  });

  final String userId;
  final String cycleId;
  final String examName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requirements = ref.watch(
      checklistRequirementsProvider(cycleId),
    );

    final checklist = ref.watch(
      studentChecklistProvider(
        (
          userId: userId,
          cycleId: cycleId,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents & Checklist'),
      ),
      body: requirements.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Unable to load checklist requirements.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (requirements) {
          if (requirements.isEmpty) {
            return _EmptyChecklist(examName: examName);
          }

          return checklist.when(
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (error, stackTrace) => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Unable to load your checklist.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            data: (studentItems) {
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: requirements.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final requirement = requirements[index];

                  final matchingItems = studentItems.where(
                    (item) => item.requirementId == requirement.id,
                  );

                  final status = matchingItems.isEmpty
                      ? ChecklistItemStatus.pending
                      : matchingItems.first.status;

                  return CheckboxListTile(
                    value: status == ChecklistItemStatus.completed,
                    title: Text(requirement.label),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (checked) async {
                      await ref
                          .read(checklistRepositoryProvider)
                          .updateItem(
                            userId: userId,
                            cycleId: cycleId,
                            item: StudentChecklistItem(
                              requirementId: requirement.id,
                              status: checked == true
                                  ? ChecklistItemStatus.completed
                                  : ChecklistItemStatus.pending,
                              updatedAt: DateTime.now(),
                            ),
                          );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyChecklist extends StatelessWidget {
  const _EmptyChecklist({
    required this.examName,
  });

  final String examName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.checklist_rounded,
              size: 72,
            ),
            const SizedBox(height: 16),
            Text(
              examName,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'No verified checklist requirements have been added yet.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
