import 'package:meta/meta.dart';

import 'violation.dart';

/// The result of a call to [StateFence.transition].
sealed class TransitionResult<S> {
  const TransitionResult._();
}

/// A state transition that was accepted by the fence rules.
@immutable
final class TransitionAccepted<S> extends TransitionResult<S> {
  /// The new current state after the transition.
  final S state;

  /// Creates an accepted result containing [state].
  const TransitionAccepted(this.state) : super._();
}

/// A state transition that was rejected by the fence rules.
@immutable
final class TransitionRejected<S> extends TransitionResult<S> {
  /// A structured record of why the transition was rejected.
  final StateFenceViolation violation;

  /// Creates a rejected result containing [violation].
  const TransitionRejected(this.violation) : super._();
}
