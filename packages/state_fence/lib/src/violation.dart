import 'package:meta/meta.dart';

/// A structured record of a state transition that violated a [StateFence].
///
/// The model stores state types, not the state objects themselves, to avoid
/// automatically exposing arbitrary application state. Metadata is opt-in.
@immutable
final class StateFenceViolation {
  /// The name of the fence that rejected the transition.
  final String fenceName;

  /// The runtime type of the previous state.
  final Type previousState;

  /// The runtime type of the attempted state.
  final Type attemptedState;

  /// When the violation occurred.
  final DateTime timestamp;

  /// An optional operation identifier supplied at the transition call site.
  final String? operation;

  /// Metadata supplied by the caller. Safe values only are recorded.
  final Map<String, Object?> safeMetadata;

  /// The stack trace at the point of rejection, when capture is enabled.
  final StackTrace? stackTrace;

  /// A human-readable explanation of the rejection.
  final String reason;

  /// Creates a violation record.
  StateFenceViolation({
    required this.fenceName,
    required this.previousState,
    required this.attemptedState,
    required this.timestamp,
    this.operation,
    this.safeMetadata = const {},
    this.stackTrace,
    required this.reason,
  });

  @override
  String toString() => reason;
}
