import 'violation.dart';

/// Receives [StateFenceViolation]s from a [StateFence].
///
/// Implementations can log, collect, throw or forward violations to any
/// diagnostic infrastructure. The default behaviour is to ignore them.
abstract interface class StateFenceReporter {
  /// Called whenever a [StateFenceViolation] occurs.
  void report(StateFenceViolation violation);
}

/// A [StateFenceReporter] that does nothing.
///
/// This is the default reporter for [StateFence] when none is supplied.
final class DevNullReporter implements StateFenceReporter {
  /// Creates a no-op reporter.
  const DevNullReporter();

  @override
  void report(StateFenceViolation violation) {}
}
