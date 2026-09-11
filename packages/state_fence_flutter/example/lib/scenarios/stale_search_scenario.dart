import 'dart:async';

import 'package:flutter/material.dart';
import 'package:state_fence/state_fence.dart';
import 'package:state_fence_flutter/state_fence_flutter.dart';

import '../diagnostics.dart';
import '../widgets/diagnostics_panel.dart';
import '../widgets/scenario_page.dart';
import '../widgets/status_pill.dart';

/// Demonstrates a stale search response race condition.
///
/// Without StateFence, a slow older request can overwrite a newer result.
/// With [GuardedOperation] using [OperationPolicy.latestWins], the older
/// result is discarded as stale.
class StaleSearchScenario extends StatefulWidget {
  /// Creates the stale search scenario screen.
  const StaleSearchScenario({super.key});

  @override
  State<StaleSearchScenario> createState() => _StaleSearchScenarioState();
}

class _Query {
  _Query(this.term, this.delay);

  final String term;
  final Duration delay;
  StatusTone tone = StatusTone.progress;
  String status = 'In flight';
}

const Color _accent = Color(0xFF0EA5E9);

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

  List<_Query> _queries = <_Query>[];
  List<String>? _results;
  bool _running = false;

  Future<List<String>> _fakeSearch(_Query query) async {
    await Future<void>.delayed(query.delay);
    return List<String>.generate(5, (i) => '${query.term} result ${i + 1}');
  }

  Future<void> _runQuery(_Query query) async {
    final OperationOutcome<List<String>> outcome =
        await _guardedSearch.run(() => _fakeSearch(query));
    if (!mounted) return;

    setState(() {
      switch (outcome) {
        case OperationSuccess(:final value):
          query.tone = StatusTone.success;
          query.status = 'Accepted';
          _results = value;
        case OperationIgnoredAsStale():
          query.tone = StatusTone.warning;
          query.status = 'Discarded as stale';
        default:
          // Every outcome must leave the progress tone, otherwise the button
          // below stays disabled for good.
          query.tone = StatusTone.error;
          query.status = 'Not applied';
      }
      _running = _queries.any((q) => q.tone == StatusTone.progress);
    });
  }

  Future<void> _runRace() async {
    final List<_Query> queries = <_Query>[
      _Query('a', const Duration(seconds: 3)),
      _Query('ab', const Duration(seconds: 1)),
      _Query('abc', const Duration(milliseconds: 250)),
    ];

    setState(() {
      _queries = queries;
      _results = null;
      _running = true;
    });

    for (final _Query query in queries) {
      unawaited(_runQuery(query));
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return ScenarioPage(
      title: 'Stale Search',
      icon: Icons.search_rounded,
      accent: _accent,
      problem: 'A user types "a", then "ab", then "abc". The slow "a" request '
          'resolves last and overwrites the newer "abc" results.',
      solution:
          'latestWins accepts only the newest request. Older results that '
          'arrive late are discarded as stale, so the UI stays correct.',
      children: [
        FilledButton.icon(
          onPressed: _running ? null : _runRace,
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(_running ? 'Running race...' : 'Run the search race'),
        ),
        if (_queries.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Requests',
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ..._queries.map(
            (q) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'search("${q.term}")  •  ${q.delay.inMilliseconds} ms',
                      style: text.bodyMedium,
                    ),
                  ),
                  StatusPill(
                    label: q.status,
                    tone: q.tone,
                    icon: switch (q.tone) {
                      StatusTone.success => Icons.check_rounded,
                      StatusTone.warning => Icons.delete_sweep_outlined,
                      _ => Icons.autorenew_rounded,
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
        if (_results != null) ...[
          const SizedBox(height: 12),
          Card(
            color: scheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Displayed results',
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._results!.map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 18,
                            color: scheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            r,
                            style: text.bodyMedium?.copyWith(
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        DiagnosticsPanel(
          violations: _diag.reporter.violations,
          eventCount: _diag.timeline.length,
        ),
      ],
    );
  }
}
