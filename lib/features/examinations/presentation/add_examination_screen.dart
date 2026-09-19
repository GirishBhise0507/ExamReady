import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/examination_providers.dart';
import '../domain/examination.dart';
import 'examination_cycle_screen.dart';

class AddExaminationScreen extends ConsumerStatefulWidget {
  const AddExaminationScreen({super.key});

  @override
  ConsumerState<AddExaminationScreen> createState() =>
      _AddExaminationScreenState();
}

class _AddExaminationScreenState
    extends ConsumerState<AddExaminationScreen> {
  final _searchController = TextEditingController();

  List<Examination> _results = const [];
  bool _isSearching = false;
  String? _errorMessage;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _results = const [];
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final repository = ref.read(examinationCatalogRepositoryProvider);

      final results = await repository.search(query: query);

      if (!mounted) {
        return;
      }

      setState(() {
        _results = results;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Unable to search examinations.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Exam'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                labelText: 'Search examination',
                hintText: 'Example: JEE Main',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: _search,
                  icon: const Icon(Icons.arrow_forward),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            if (_isSearching)
              const CircularProgressIndicator()
            else if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              )
            else if (_results.isEmpty &&
                _searchController.text.trim().isNotEmpty)
              const Text('No examinations found.')
            else
              Expanded(
                child: ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final examination = _results[index];

                    return ListTile(
                      leading: const Icon(Icons.school_outlined),
                      title: Text(examination.name),
                      subtitle: examination.aliases.isEmpty
                          ? null
                          : Text(examination.aliases.join(', ')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ExaminationCycleScreen(
                              examination: examination,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

