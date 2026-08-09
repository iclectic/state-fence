import 'dart:async';

import 'package:flutter/material.dart';
import 'package:state_fence/state_fence.dart';
import 'package:state_fence_flutter/state_fence_flutter.dart';

import '../main.dart';
import '../widgets/violations_panel.dart';

/// Demonstrates a stale search response race condition.
///
/// Without StateFence, a slow older request can overwrite a newer result.
/// With [GuardedOperation] using [OperationPolicy.latestWins], the older
/// result is discarded as stale.
class StaleSearchScenario extends StatefulWidget {
  const StaleSearchScenario({super.key});

  @override
  State<StaleSearchScenario> createState() => _StaleSearchScenarioState();
}

class _StaleSearchScenarioState extends State<StaleSearchScenario>
    with StateFenceStateMixin {
  late final SharedDiagnostics _diag = SharedDiagnostics();
  late final GuardedOperation<List<String>> _guardedSearch =
      fenceOwner.register(
    GuardedOperation<List<String>>(
      name: 'search',
      policy: OperationPolicy.latestWins,
      reporter: _diag.reporter,
      timeline: _diag.timeline,
    ),
  );

  List<String>? _results;
  String _statusText = 'Type a query to search.';

  Future<List<String>> _fakeSearch(String query, Duration delay) async {
    await Future<void>.delayed(delay);
    return List.generate(5, (i) => '$query result ${i + 1}');
  }

  Future<void> _runSearch(String query, Duration delay) async {
    setState(() {
      _statusText = 'Searching for "$query"...';
    });

    final outcome = await _guardedSearch.run(
      () => _fakeSearch(query, delay),
    );

    if (!mounted) return;

    if (outcome case OperationSuccess(:final value)) {
      setState(() {
        _results = value;
        _statusText = 'Showing results for "$query".';
      });
    } else if (outcome case OperationIgnoredAsStale()) {
      setState(() {
        _statusText = 'Stale result discarded for "$query".';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stale Search')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This scenario fires three searches with different delays. '
              'The slowest query resolves last. Without latestWins, it would '
              'overwrite the newer result.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () => _runSearch('a', const Duration(seconds: 3)),
                  child: const Text('Search "a" (slow)'),
                ),
                ElevatedButton(
                  onPressed: () => _runSearch('ab', const Duration(seconds: 1)),
                  child: const Text('Search "ab" (medium)'),
                ),
                ElevatedButton(
                  onPressed: () =>
                      _runSearch('abc', const Duration(milliseconds: 200)),
                  child: const Text('Search "abc" (fast)'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(_statusText),
            const SizedBox(height: 16),
            if (_results != null)
              Expanded(
                child: ListView(
                  children: _results!
                      .map((r) => ListTile(
                            leading: const Icon(Icons.search),
                            title: Text(r),
                          ))
                      .toList(),
                ),
              )
            else
              const Expanded(child: Center(child: Text('No results yet.'))),
            const SizedBox(height: 8),
            ViolationsPanel(
              violations: _diag.reporter.violations,
              eventCount: _diag.timeline.length,
            ),
          ],
        ),
      ),
    );
  }
}
