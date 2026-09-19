import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/examination_providers.dart';
import 'add_examination_screen.dart';
import 'my_exam_card.dart';

class MyExamsScreen extends ConsumerWidget {
  const MyExamsScreen({super.key});

  Future<void> _refresh(
    WidgetRef ref,
  ) async {
    ref.invalidate(
      selectedExaminationsProvider,
    );

    try {
      await ref.read(
        selectedExaminationsProvider.future,
      );
    } catch (_) {
      // The screen itself will show the error state.
    }
  }

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final selectedExaminations =
        ref.watch(
      selectedExaminationsProvider,
    );

    return Scaffold(
      body: selectedExaminations.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),

        error: (error, stackTrace) => Center(
          child: Padding(
            padding:
                const EdgeInsets.all(24),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  'Unable to load your examinations.',
                  textAlign:
                      TextAlign.center,
                  style:
                      Theme.of(context)
                          .textTheme
                          .titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please check your connection and try again.',
                  textAlign:
                      TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed:
                      () => _refresh(ref),
                  icon:
                      const Icon(
                    Icons.refresh_rounded,
                  ),
                  label:
                      const Text(
                    'Retry',
                  ),
                ),
              ],
            ),
          ),
        ),

        data: (examinations) {
          return RefreshIndicator(
            onRefresh:
                () => _refresh(ref),
            child: examinations.isEmpty
                ? ListView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding:
                        const EdgeInsets.all(24),
                    children: [
                      SizedBox(
                        height:
                            MediaQuery.sizeOf(
                                  context,
                                ).height *
                                0.55,
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .center,
                          children: [
                            Icon(
                              Icons.school_outlined,
                              size: 80,
                              color:
                                  Theme.of(context)
                                      .colorScheme
                                      .primary,
                            ),
                            const SizedBox(
                              height: 20,
                            ),
                            Text(
                              'No Exams Added Yet',
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
                              'Add an examination to keep its '
                              'important information and updates '
                              'in one place.',
                              textAlign:
                                  TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding:
                        const EdgeInsets.all(16),
                    itemCount:
                        examinations.length,
                    separatorBuilder:
                        (_, __) =>
                            const SizedBox(
                      height: 8,
                    ),
                    itemBuilder:
                        (context, index) {
                      final examination =
                          examinations[index];

                      return MyExamCard(
                        studentExamination:
                            examination,
                      );
                    },
                  ),
          );
        },
      ),

      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  const AddExaminationScreen(),
            ),
          );
        },
        icon:
            const Icon(Icons.add),
        label:
            const Text('Add Exam'),
      ),
    );
  }
}
