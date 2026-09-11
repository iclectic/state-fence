import 'package:meta/meta.dart';

import 'operation_token.dart';
import 'violation.dart';

/// A bounded diagnostic event recorded by a [StateFence] or
/// [GuardedOperation].
///
/// Events are immutable values. They never carry arbitrary application state;
/// only opt-in metadata is recorded, and it must be redacted before export.
sealed class FenceEvent {
  /// The name of the fence or operation that produced this event.
  final String source;

  /// When the event occurred.
  final DateTime timestamp;

  /// Optional operation identifier supplied at the call site.
  final String? operation;

  /// Opt-in metadata supplied by the caller. Safe values only.
  final Map<String, Object?> metadata;

  const FenceEvent._({
    required this.source,
    required this.timestamp,
    this.operation,
    this.metadata = const {},
  });

  /// A short machine-readable kind name for this event, such as
  /// `transitionAccepted` or `operationTimedOut`.
  String get kind;
}

/// A state transition was accepted by a [StateFence].
@immutable
final class TransitionAcceptedEvent extends FenceEvent {
  /// The runtime type of the previous state.
  final Type fromState;

  /// The runtime type of the new state.
  final Type toState;

  /// Creates an accepted-transition event from [fromState] to [toState].
  const TransitionAcceptedEvent({
    required super.source,
    required super.timestamp,
    super.operation,
    super.metadata,
    required this.fromState,
    required this.toState,
  }) : super._();

  @override
  String get kind => 'transitionAccepted';
}

/// A state transition was rejected by a [StateFence].
@immutable
final class TransitionRejectedEvent extends FenceEvent {
  /// The violation describing why the transition was rejected.
  final StateFenceViolation violation;

  /// Creates a rejected-transition event describing [violation].
  const TransitionRejectedEvent({
    required super.source,
    required super.timestamp,
    super.operation,
    super.metadata,
    required this.violation,
  }) : super._();

  @override
  String get kind => 'transitionRejected';
}

/// A guarded operation invocation started.
@immutable
final class OperationStartedEvent extends FenceEvent {
  /// The token identifying the invocation.
  final OperationToken token;

  /// Creates a started event for the invocation identified by [token].
  const OperationStartedEvent({
    required super.source,
    required super.timestamp,
    super.operation,
    super.metadata,
    required this.token,
  }) : super._();

  @override
  String get kind => 'operationStarted';
}

/// A guarded operation completed successfully and was accepted.
@immutable
final class OperationSucceededEvent extends FenceEvent {
  /// The token identifying the invocation.
  final OperationToken token;

  /// Creates a succeeded event for the invocation identified by [token].
  const OperationSucceededEvent({
    required super.source,
    required super.timestamp,
    super.operation,
    super.metadata,
    required this.token,
  }) : super._();

  @override
  String get kind => 'operationSucceeded';
}

/// A guarded operation failed and the failure was accepted.
@immutable
final class OperationFailedEvent extends FenceEvent {
  /// The token identifying the invocation.
  final OperationToken token;

  /// A short description of the error. The full error object is not captured.
  final String errorDescription;

  /// Creates a failed event for [token] described by [errorDescription].
  const OperationFailedEvent({
    required super.source,
    required super.timestamp,
    super.operation,
    super.metadata,
    required this.token,
    required this.errorDescription,
  }) : super._();

  @override
  String get kind => 'operationFailed';
}

/// A guarded operation result was ignored because a newer invocation had
/// already been accepted.
@immutable
final class OperationIgnoredAsStaleEvent extends FenceEvent {
  /// The token of the ignored invocation.
  final OperationToken token;

  /// The token of the newer invocation that superseded this one.
  final OperationToken supersededBy;

  /// Creates a stale-ignored event for [token], superseded by [supersededBy].
  const OperationIgnoredAsStaleEvent({
    required super.source,
    required super.timestamp,
    super.operation,
    super.metadata,
    required this.token,
    required this.supersededBy,
  }) : super._();

  @override
  String get kind => 'operationIgnoredAsStale';
}

/// A guarded operation invocation was ignored because another was already in
/// flight.
@immutable
final class OperationIgnoredAsDuplicateEvent extends FenceEvent {
  /// The token of the ignored invocation.
  final OperationToken token;

  /// The token of the in-flight invocation that took precedence.
  final OperationToken blockedBy;

  /// Creates a duplicate-ignored event for [token], blocked by [blockedBy].
  const OperationIgnoredAsDuplicateEvent({
    required super.source,
    required super.timestamp,
    super.operation,
    super.metadata,
    required this.token,
    required this.blockedBy,
  }) : super._();

  @override
  String get kind => 'operationIgnoredAsDuplicate';
}

/// A guarded operation timed out.
@immutable
final class OperationTimedOutEvent extends FenceEvent {
  /// The token identifying the invocation that timed out.
  final OperationToken token;

  /// Creates a timed-out event for the invocation identified by [token].
  const OperationTimedOutEvent({
    required super.source,
    required super.timestamp,
    super.operation,
    super.metadata,
    required this.token,
  }) : super._();

  @override
  String get kind => 'operationTimedOut';
}

/// A state remained active for longer than its declared maximum duration.
@immutable
final class StateStuckEvent extends FenceEvent {
  /// The runtime type of the state that became stuck.
  final Type stuckState;

  /// The declared maximum duration that was exceeded.
  final Duration maxDuration;

  /// Creates a stuck-state event for [stuckState] exceeding [maxDuration].
  const StateStuckEvent({
    required super.source,
    required super.timestamp,
    super.operation,
    super.metadata,
    required this.stuckState,
    required this.maxDuration,
  }) : super._();

  @override
  String get kind => 'stateStuck';
}

/// A fence or operation was disposed.
@immutable
final class OwnerDisposedEvent extends FenceEvent {
  /// Creates a disposal event for the fence or operation named [source].
  const OwnerDisposedEvent({
    required super.source,
    required super.timestamp,
    super.operation,
    super.metadata,
  }) : super._();

  @override
  String get kind => 'ownerDisposed';
}
