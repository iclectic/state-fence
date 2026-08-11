import 'package:meta/meta.dart';

import 'operation_token.dart';

/// The outcome of a [GuardedOperation.run] call.
sealed class OperationOutcome<T> {
  /// The token identifying the invocation that produced this outcome.
  final OperationToken token;

  const OperationOutcome._(this.token);
}

/// The operation completed successfully and its result was accepted.
@immutable
final class OperationSuccess<T> extends OperationOutcome<T> {
  /// The value returned by the operation.
  final T value;

  /// Creates a successful outcome.
  const OperationSuccess(super.token, this.value) : super._();

  /// A string representation, such as `OperationSuccess<int>(token: 3)`.
  @override
  String toString() => 'OperationSuccess<$T>(token: ${token.value})';
}

/// The operation failed by throwing and the failure was accepted.
@immutable
final class OperationFailure<T> extends OperationOutcome<T> {
  /// The error thrown by the operation.
  final Object error;

  /// The stack trace captured at the point of failure, when available.
  final StackTrace stackTrace;

  /// Creates a failure outcome.
  const OperationFailure(super.token, this.error, this.stackTrace) : super._();

  /// A string representation including the error.
  @override
  String toString() => 'OperationFailure<$T>(token: ${token.value}, $error)';
}

/// The result was discarded because a newer invocation had already been
/// accepted. Only produced under [OperationPolicy.latestWins].
@immutable
final class OperationIgnoredAsStale<T> extends OperationOutcome<T> {
  /// The token of the newer invocation that superseded this one.
  final OperationToken supersededBy;

  /// Creates a stale-ignored outcome.
  const OperationIgnoredAsStale(super.token, this.supersededBy) : super._();

  /// A string representation including the superseding token.
  @override
  String toString() => 'OperationIgnoredAsStale<$T>(token: ${token.value}, '
      'supersededBy: ${supersededBy.value})';
}

/// The invocation was ignored because another operation was already in flight.
/// Only produced under [OperationPolicy.firstWins].
@immutable
final class OperationIgnoredAsDuplicate<T> extends OperationOutcome<T> {
  /// The token of the in-flight invocation that took precedence.
  final OperationToken blockedBy;

  /// Creates a duplicate-ignored outcome.
  const OperationIgnoredAsDuplicate(super.token, this.blockedBy) : super._();

  /// A string representation including the blocking token.
  @override
  String toString() => 'OperationIgnoredAsDuplicate<$T>(token: ${token.value}, '
      'blockedBy: ${blockedBy.value})';
}

/// The invocation exceeded its configured timeout before completing.
///
/// The [GuardedOperation.run] future resolves with this outcome as soon as
/// the timeout fires, so callers are never left waiting on a stuck operation.
/// If the underlying action completes later, its result is discarded.
@immutable
final class OperationTimedOut<T> extends OperationOutcome<T> {
  /// The configured timeout that was exceeded.
  final Duration timeout;

  /// Creates a timed-out outcome.
  const OperationTimedOut(super.token, this.timeout) : super._();

  /// A string representation including the timeout duration.
  @override
  String toString() =>
      'OperationTimedOut<$T>(token: ${token.value}, timeout: $timeout)';
}
