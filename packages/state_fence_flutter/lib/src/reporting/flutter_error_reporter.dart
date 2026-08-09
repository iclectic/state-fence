import 'package:flutter/foundation.dart';
import 'package:state_fence/state_fence.dart';

/// A [StateFenceReporter] that forwards violations to [FlutterError.reportError].
///
/// This bridges StateFence violations into the standard Flutter error
/// reporting pipeline, making them visible in the debug console and any
/// registered error handlers. Use this in debug or profile builds to surface
/// violations alongside other Flutter framework errors.
class FlutterErrorReporter implements StateFenceReporter {
  /// Creates a reporter that forwards to [FlutterError.reportError].
  const FlutterErrorReporter();

  /// Forwards [violation] to [FlutterError.reportError] as a
  /// [StateFenceViolationException] with diagnostic properties.
  @override
  void report(StateFenceViolation violation) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: StateFenceViolationException(violation),
        stack: violation.stackTrace,
        library: 'state_fence',
        context: ErrorDescription(violation.reason),
        informationCollector: () => [
          DiagnosticsProperty<String>('fence', violation.fenceName),
          DiagnosticsProperty<String>('operation', violation.operation),
          DiagnosticsProperty<Type>('previousState', violation.previousState),
          DiagnosticsProperty<Type>('attemptedState', violation.attemptedState),
        ],
      ),
    );
  }
}

/// An exception wrapping a [StateFenceViolation] for [FlutterErrorReporter].
///
/// This type exists so that Flutter's error pipeline receives a structured
/// exception rather than a bare string.
final class StateFenceViolationException implements Exception {
  /// The violation that caused this exception.
  final StateFenceViolation violation;

  /// Creates an exception wrapping [violation].
  const StateFenceViolationException(this.violation);

  /// Returns a string containing the violation reason.
  @override
  String toString() => 'StateFenceViolationException: ${violation.reason}';
}
