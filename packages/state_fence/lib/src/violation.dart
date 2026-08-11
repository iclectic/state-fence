import 'package:meta/meta.dart';

import 'operation_token.dart';

/// A structured record of a rule breach detected by StateFence.
///
/// Violations are a sealed hierarchy so callers can exhaustively match on the
/// specific kind. The model stores state types, not the state objects
/// themselves, to avoid automatically exposing arbitrary application state.
/// Metadata is opt-in and supplied by the caller.
sealed class StateFenceViolation {
  /// The name of the fence or operation that produced this violation.
  final String source;

  /// When the violation occurred.
  final DateTime timestamp;

  /// An optional operation identifier supplied at the call site.
  final String? operation;

  /// Metadata supplied by the caller. Safe values only are recorded.
  final Map<String, Object?> safeMetadata;

  /// The stack trace at the point of the violation, when capture is enabled.
  final StackTrace? stackTrace;

  /// A human-readable explanation of the violation.
  final String reason;

  const StateFenceViolation._({
    required this.source,
    required this.timestamp,
    this.operation,
    this.safeMetadata = const {},
    this.stackTrace,
    required this.reason,
  });

  /// Returns [reason].
  @override
  String toString() => reason;
}

/// A state transition was rejected because no rule permits it.
@immutable
final class TransitionViolation extends StateFenceViolation {
  /// The runtime type of the previous state.
  final Type previousState;

  /// The runtime type of the attempted state.
  final Type attemptedState;

  /// Creates a transition violation.
  const TransitionViolation({
    required super.source,
    required super.timestamp,
    super.operation,
    super.safeMetadata,
    super.stackTrace,
    required super.reason,
    required this.previousState,
    required this.attemptedState,
  }) : super._();
}

/// A guarded operation exceeded its configured timeout.
@immutable
final class OperationTimeoutViolation extends StateFenceViolation {
  /// The token identifying the invocation that timed out.
  final OperationToken token;

  /// The configured timeout that was exceeded.
  final Duration timeout;

  /// Creates an operation timeout violation.
  const OperationTimeoutViolation({
    required super.source,
    required super.timestamp,
    super.operation,
    super.safeMetadata,
    super.stackTrace,
    required super.reason,
    required this.token,
    required this.timeout,
  }) : super._();
}

/// A state remained active for longer than its declared maximum duration.
@immutable
final class StuckStateViolation extends StateFenceViolation {
  /// The runtime type of the state that became stuck.
  final Type stuckState;

  /// The declared maximum duration that was exceeded.
  final Duration maxDuration;

  /// Creates a stuck-state violation.
  const StuckStateViolation({
    required super.source,
    required super.timestamp,
    super.operation,
    super.safeMetadata,
    super.stackTrace,
    required super.reason,
    required this.stuckState,
    required this.maxDuration,
  }) : super._();
}

/// A fence or operation was used after it had been disposed.
@immutable
final class UseAfterDisposeViolation extends StateFenceViolation {
  /// Creates a use-after-dispose violation.
  const UseAfterDisposeViolation({
    required super.source,
    required super.timestamp,
    super.operation,
    super.safeMetadata,
    super.stackTrace,
    required super.reason,
  }) : super._();
}
