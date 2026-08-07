import 'reporter.dart';
import 'transition_result.dart';
import 'transition_rule.dart';
import 'violation.dart';

/// A type-safe contract over the valid state transitions for a domain.
///
/// [S] is the sealed or abstract supertype for the state domain. The fence
/// holds the current state and returns a structured [TransitionResult] for
/// every transition attempt. Illegal transitions are reported through an
/// injectable [StateFenceReporter] and do not change the current state.
class StateFence<S> {
  /// The name of this fence, used in violations and diagnostics.
  final String name;

  final List<TransitionRule> _rules;
  final StateFenceReporter _reporter;
  final bool _captureStackTrace;
  S _currentState;

  /// Creates a fence with the given [initialState] and [rules].
  ///
  /// [reporter] is called whenever a transition is rejected. If omitted, a
  /// [DevNullReporter] is used. [captureStackTrace] records a stack trace on
  /// every rejection when true.
  StateFence({
    required this.name,
    required S initialState,
    required List<TransitionRule> rules,
    StateFenceReporter? reporter,
    bool captureStackTrace = false,
  })  : _currentState = initialState,
        _rules = List.unmodifiable(rules),
        _reporter = reporter ?? const DevNullReporter(),
        _captureStackTrace = captureStackTrace;

  /// The current state of this fence.
  S get current => _currentState;

  /// Attempts to transition the current state to [newState].
  ///
  /// [operation] and [metadata] are copied into any resulting
  /// [StateFenceViolation] without modification. No automatic serialisation of
  /// arbitrary state occurs.
  TransitionResult<S> transition(
    S newState, {
    String? operation,
    Map<String, Object?>? metadata,
  }) {
    final previous = _currentState;
    final previousType = previous.runtimeType;
    final attemptedType = newState.runtimeType;

    for (final rule in _rules) {
      if (rule.allows(previousType, attemptedType)) {
        _currentState = newState;
        return TransitionAccepted(newState);
      }
    }

    final violation = StateFenceViolation(
      fenceName: name,
      previousState: previousType,
      attemptedState: attemptedType,
      timestamp: DateTime.now(),
      operation: operation,
      safeMetadata: Map<String, Object?>.unmodifiable(metadata ?? const {}),
      stackTrace: _captureStackTrace ? StackTrace.current : null,
      reason: 'Transition from $previousType to $attemptedType is not allowed '
          'by any rule for fence "$name".',
    );

    _reporter.report(violation);
    return TransitionRejected(violation);
  }
}
