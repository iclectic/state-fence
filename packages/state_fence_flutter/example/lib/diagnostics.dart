import 'package:state_fence/state_fence.dart';

/// A shared [Timeline] and [StateFenceReporter] used by the example scenarios
/// to surface diagnostic activity in the UI.
class SharedDiagnostics {
  /// Creates a fresh timeline and collecting reporter.
  SharedDiagnostics();

  /// Bounded diagnostic timeline that records fence and operation events.
  final Timeline timeline = Timeline(capacity: 256);

  /// Reporter that collects violations so the UI can display them.
  final CollectingReporter reporter = CollectingReporter();
}

/// A simple [StateFenceReporter] that stores violations in memory.
///
/// This is a development aid for the example app. It is not part of the
/// public StateFence API.
class CollectingReporter implements StateFenceReporter {
  /// Violations reported so far, in the order they were received.
  final List<StateFenceViolation> violations = <StateFenceViolation>[];

  @override
  void report(StateFenceViolation violation) {
    violations.add(violation);
  }
}
