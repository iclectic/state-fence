import 'package:meta/meta.dart';

/// Opt-in retry for a failed [GuardedOperation] attempt.
///
/// This is not a data client. It reruns the same action after a failure,
/// with a delay between attempts. It does not inspect HTTP responses, and it
/// does not retry a timeout or an ignored outcome.
///
/// [maxAttempts] includes the first run. A value of `1` disables retries.
@immutable
final class RetryPolicy {
  /// Creates a retry policy.
  ///
  /// [maxAttempts] and [multiplier] must be at least 1. [initialDelay] is the
  /// wait after the first failure. Later waits multiply that delay by
  /// [multiplier] and never exceed [maxDelay].
  const RetryPolicy({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 200),
    this.multiplier = 2,
    this.maxDelay = const Duration(seconds: 30),
  })  : assert(maxAttempts >= 1, 'maxAttempts must be at least 1'),
        assert(multiplier >= 1, 'multiplier must be at least 1');

  /// How many times the action may run, including the first attempt.
  final int maxAttempts;

  /// Delay after the first failed attempt.
  final Duration initialDelay;

  /// Factor applied to the delay after each further failure.
  final int multiplier;

  /// Upper bound for a single backoff delay.
  final Duration maxDelay;

  /// The delay to wait after [failedAttempts] failures, starting at 1.
  Duration delayAfter(int failedAttempts) {
    if (failedAttempts <= 1) {
      return initialDelay > maxDelay ? maxDelay : initialDelay;
    }
    var micros = initialDelay.inMicroseconds;
    final cap = maxDelay.inMicroseconds;
    for (var i = 1; i < failedAttempts; i++) {
      final next = micros * multiplier;
      if (next <= 0 || next >= cap) return maxDelay;
      micros = next;
    }
    return Duration(microseconds: micros);
  }
}
