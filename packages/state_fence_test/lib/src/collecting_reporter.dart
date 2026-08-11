import 'package:state_fence/state_fence.dart';

/// A [StateFenceReporter] that collects every violation for later assertions.
///
/// ```dart
/// final reporter = CollectingReporter();
/// final fence = StateFence<MyState>(..., reporter: reporter);
///
/// fence.transition(const IllegalState());
///
/// expect(reporter.violations, hasLength(1));
/// expect(reporter.hasViolations, isTrue);
/// ```
class CollectingReporter implements StateFenceReporter {
  final List<StateFenceViolation> _violations = [];

  /// The violations reported so far, in order.
  List<StateFenceViolation> get violations => List.unmodifiable(_violations);

  /// Whether any violation has been reported.
  bool get hasViolations => _violations.isNotEmpty;

  /// The violations of type [V] reported so far, in order.
  List<V> violationsOfType<V extends StateFenceViolation>() =>
      _violations.whereType<V>().toList();

  /// Removes all collected violations.
  void clear() => _violations.clear();

  @override
  void report(StateFenceViolation violation) => _violations.add(violation);
}

/// A [StateFenceReporter] that throws a [StateError] on the first violation.
///
/// Useful in strict tests where any violation should fail the test
/// immediately with the violation's reason.
class ThrowingReporter implements StateFenceReporter {
  /// Creates a reporter that throws on report.
  const ThrowingReporter();

  @override
  void report(StateFenceViolation violation) {
    throw StateError('StateFence violation: ${violation.reason}');
  }
}
