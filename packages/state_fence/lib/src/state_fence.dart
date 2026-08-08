import 'fence_clock.dart';
import 'fence_event.dart';
import 'reporter.dart';
import 'timeline.dart';
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
  final FenceClock _clock;
  final Timeline? _timeline;
  bool _disposed = false;

  /// Creates a fence with the given [initialState] and [rules].
  ///
  /// [reporter] is called whenever a transition is rejected. If omitted, a
  /// [DevNullReporter] is used. [captureStackTrace] records a stack trace on
  /// every rejection when true. [clock] controls timestamps for deterministic
  /// tests. [timeline], when supplied, records bounded diagnostic events.
  StateFence({
    required this.name,
    required S initialState,
    required List<TransitionRule> rules,
    StateFenceReporter? reporter,
    bool captureStackTrace = false,
    FenceClock? clock,
    Timeline? timeline,
  })  : _currentState = initialState,
        _rules = List.unmodifiable(rules),
        _reporter = reporter ?? const DevNullReporter(),
        _captureStackTrace = captureStackTrace,
        _clock = clock ?? const RealFenceClock(),
        _timeline = timeline;

  S _currentState;

  /// The current state of this fence.
  S get current => _currentState;

  /// Whether this fence has been disposed.
  bool get isDisposed => _disposed;

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
    if (_disposed) {
      final violation = StateFenceViolation(
        fenceName: name,
        previousState: _currentState.runtimeType,
        attemptedState: newState.runtimeType,
        timestamp: _clock.now(),
        operation: operation,
        reason: 'Fence "$name" was used after dispose.',
      );
      _safeReport(violation);
      _timeline?.add(
        OwnerDisposedEvent(
          source: name,
          timestamp: violation.timestamp,
          operation: operation,
          metadata: Map<String, Object?>.unmodifiable(metadata ?? const {}),
        ),
      );
      return TransitionRejected(violation);
    }

    final previous = _currentState;
    final previousType = previous.runtimeType;
    final attemptedType = newState.runtimeType;
    final now = _clock.now();
    final safeMetadata =
        Map<String, Object?>.unmodifiable(metadata ?? const {});

    for (final rule in _rules) {
      if (rule.allows(previousType, attemptedType)) {
        _currentState = newState;
        _timeline?.add(
          TransitionAcceptedEvent(
            source: name,
            timestamp: now,
            operation: operation,
            metadata: safeMetadata,
            fromState: previousType,
            toState: attemptedType,
          ),
        );
        return TransitionAccepted(newState);
      }
    }

    final violation = StateFenceViolation(
      fenceName: name,
      previousState: previousType,
      attemptedState: attemptedType,
      timestamp: now,
      operation: operation,
      safeMetadata: safeMetadata,
      stackTrace: _captureStackTrace ? StackTrace.current : null,
      reason: 'Transition from $previousType to $attemptedType is not allowed '
          'by any rule for fence "$name".',
    );

    _safeReport(violation);
    _timeline?.add(
      TransitionRejectedEvent(
        source: name,
        timestamp: now,
        operation: operation,
        metadata: safeMetadata,
        violation: violation,
      ),
    );
    return TransitionRejected(violation);
  }

  void _safeReport(StateFenceViolation violation) {
    try {
      _reporter.report(violation);
    } catch (_) {
      // Reporter failures are isolated so timeline recording is not lost.
    }
  }

  /// Disposes this fence.
  ///
  /// Subsequent transition attempts report a violation and record an
  /// [OwnerDisposedEvent] when a timeline is attached.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timeline?.add(
      OwnerDisposedEvent(
        source: name,
        timestamp: _clock.now(),
      ),
    );
  }
}
