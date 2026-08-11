import 'violation.dart';

/// Receives [StateFenceViolation]s from a [StateFence] or [GuardedOperation].
///
/// Implementations can log, collect, throw or forward violations to any
/// diagnostic infrastructure. The default behaviour is to ignore them.
///
/// ## Throwing reporters and strict mode
///
/// A reporter that throws enables strict mode: violations raised from
/// synchronous call sites, such as [StateFence.transition], propagate the
/// exception to the caller. Timeline events are always recorded before the
/// reporter is invoked, so diagnostics are never lost to a throwing reporter.
///
/// Violations raised from asynchronous timer callbacks, such as operation
/// timeouts and stuck-state detection, isolate reporter exceptions because
/// there is no caller to receive them.
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
