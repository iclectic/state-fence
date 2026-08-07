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
}

/// The result was discarded because a newer invocation had already been
/// accepted. Only produced under [OperationPolicy.latestWins].
@immutable
final class OperationIgnoredAsStale<T> extends OperationOutcome<T> {
  /// The token of the newer invocation that superseded this one.
  final OperationToken supersededBy;

  /// Creates a stale-ignored outcome.
  const OperationIgnoredAsStale(super.token, this.supersededBy) : super._();
}

/// The invocation was ignored because another operation was already in flight.
/// Only produced under [OperationPolicy.firstWins].
@immutable
final class OperationIgnoredAsDuplicate<T> extends OperationOutcome<T> {
  /// The token of the in-flight invocation that took precedence.
  final OperationToken blockedBy;

  /// Creates a duplicate-ignored outcome.
  const OperationIgnoredAsDuplicate(super.token, this.blockedBy) : super._();
}
