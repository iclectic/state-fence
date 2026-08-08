import 'package:flutter/material.dart';
import 'package:state_fence/state_fence.dart';
import 'package:state_fence_flutter/state_fence_flutter.dart';

import 'scenarios/duplicate_submission_scenario.dart';
import 'scenarios/stale_search_scenario.dart';
import 'scenarios/stuck_loading_scenario.dart';

void main() {
  runApp(const StateFenceExampleApp());
}

class StateFenceExampleApp extends StatelessWidget {
  const StateFenceExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StateFence Example',
      theme: ThemeData.light(useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true),
      home: const ScenarioSelector(),
    );
  }
}

class ScenarioSelector extends StatelessWidget {
  const ScenarioSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('StateFence Examples')),
      body: ListView(
        children: const [
          _ScenarioTile(
            title: 'Stale search response',
            subtitle: 'Older results overwriting newer ones',
            destination: StaleSearchScenario(),
          ),
          _ScenarioTile(
            title: 'Duplicate submission',
            subtitle: 'Pay button tapped twice',
            destination: DuplicateSubmissionScenario(),
          ),
          _ScenarioTile(
            title: 'Stuck loading state',
            subtitle: 'A loading state that never resolves',
            destination: StuckLoadingScenario(),
          ),
        ],
      ),
    );
  }
}

class _ScenarioTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget destination;

  const _ScenarioTile({
    required this.title,
    required this.subtitle,
    required this.destination,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => destination),
        );
      },
    );
  }
}

/// A shared timeline and reporter for demonstration purposes.
class SharedDiagnostics {
  SharedDiagnostics();

  final Timeline timeline = Timeline(capacity: 256);
  final CollectingReporter reporter = CollectingReporter();
}

/// A simple collecting reporter used in the example to display violations.
class CollectingReporter implements StateFenceReporter {
  final List<StateFenceViolation> violations = [];

  @override
  void report(StateFenceViolation violation) {
    violations.add(violation);
  }
}
