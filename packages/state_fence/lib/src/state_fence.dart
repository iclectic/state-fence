import 'disposable.dart';
import 'fence_clock.dart';
import 'fence_event.dart';
import 'fence_scheduler.dart';
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
///
/// ## Stuck-state detection
///
/// Transitional states such as `Loading` or `Submitting` can be given a
/// maximum duration via [stuckStateTimeouts]. If the fence remains in such a
/// state beyond its declared duration, a [StuckStateViolation] is reported
/// and a [StateStuckEvent] is recorded. Detection is driven by the injectable
/// [FenceScheduler], so tests never rely on real waiting.
class StateFence<S> implements Disposable {
  /// The name of this fence, used in violations and diagnostics.
  final String name;

  /// Maximum durations for transitional states, keyed by state type.
  ///
  /// When the fence enters a state whose runtime type appears in this map, a
  /// timer starts. If the fence has not left that state when the timer fires,
  /// a [StuckStateViolation] is reported. Leaving the state cancels the timer.
  final Map<Type, Duration> stuckStateTimeouts;

  final List<TransitionRule> _rules;
  final StateFenceReporter _reporter;
  final bool _captureStackTrace;
  final FenceClock _clock;
  final FenceScheduler _scheduler;
  final Timeline? _timeline;
  FenceTimerHandle? _stuckTimer;
  bool _disposed = false;

  /// Creates a fence with the given [initialState] and [rules].
  ///
  /// [reporter] is called whenever a transition is rejected or a state
  /// becomes stuck. If omitted, a [DevNullReporter] is used.
  /// [captureStackTrace] records a stack trace on every rejection when true.
  /// [clock] controls timestamps and [scheduler] drives stuck-state timers;
  /// both are injectable for deterministic tests. [timeline], when supplied,
  /// records bounded diagnostic events. [stuckStateTimeouts] declares maximum
  /// durations for transitional states; detection starts immediately if the
  /// initial state has a declared timeout.
  StateFence({
    required this.name,
    required S initialState,
    required List<TransitionRule> rules,
    StateFenceReporter? reporter,
    bool captureStackTrace = false,
    FenceClock? clock,
    FenceScheduler? scheduler,
    Timeline? timeline,
    this.stuckStateTimeouts = const {},
  })  : _currentState = initialState,
        _rules = List.unmodifiable(rules),
        _reporter = reporter ?? const DevNullReporter(),
        _captureStackTrace = captureStackTrace,
        _clock = clock ??
            (scheduler != null
                ? FenceSchedulerClock(scheduler)
                : const RealFenceClock()),
        _scheduler = scheduler ?? const RealFenceScheduler(),
        _timeline = timeline {
    _armStuckTimer(initialState.runtimeType);
  }

  S _currentState;

  /// The current state of this fence.
  S get current => _currentState;

  /// Whether this fence has been disposed.
  @override
  bool get isDisposed => _disposed;

  /// Whether any rule permits a transition from state type [from] to state
  /// type [to], without performing a transition.
  bool wouldAllow({required Type from, required Type to}) =>
      _rules.any((rule) => rule.allows(from, to));

  /// Whether any rule permits a transition from the current state to state
  /// type [to], without performing a transition.
  bool canTransitionTo(Type to) =>
      wouldAllow(from: _currentState.runtimeType, to: to);

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
    final safeMetadata =
        Map<String, Object?>.unmodifiable(metadata ?? const {});

    if (_disposed) {
      final violation = UseAfterDisposeViolation(
        source: name,
        timestamp: _clock.now(),
        operation: operation,
        safeMetadata: safeMetadata,
        reason: 'Fence "$name" was used after dispose.',
      );
      _timeline?.add(
        TransitionRejectedEvent(
          source: name,
          timestamp: violation.timestamp,
          operation: operation,
          metadata: safeMetadata,
          violation: violation,
        ),
      );
      _reporter.report(violation);
      return TransitionRejected(violation);
    }

    final previousType = _currentState.runtimeType;
    final attemptedType = newState.runtimeType;
    final now = _clock.now();

    for (final rule in _rules) {
      if (rule.allows(previousType, attemptedType)) {
        _currentState = newState;
        _stuckTimer?.cancel();
        _armStuckTimer(attemptedType);
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

    final violation = TransitionViolation(
      source: name,
      timestamp: now,
      operation: operation,
      safeMetadata: safeMetadata,
      stackTrace: _captureStackTrace ? StackTrace.current : null,
      reason: 'Transition from $previousType to $attemptedType is not allowed '
          'by any rule for fence "$name".',
      previousState: previousType,
      attemptedState: attemptedType,
    );

    _timeline?.add(
      TransitionRejectedEvent(
        source: name,
        timestamp: now,
        operation: operation,
        metadata: safeMetadata,
        violation: violation,
      ),
    );
    _reporter.report(violation);
    return TransitionRejected(violation);
  }

  void _armStuckTimer(Type stateType) {
    final maxDuration = stuckStateTimeouts[stateType];
    if (maxDuration == null) {
      // Drop the reference to the cancelled timer of the previous state so a
      // long-lived fence does not retain it.
      _stuckTimer = null;
      return;
    }
    _stuckTimer = _scheduler.timer(maxDuration, () {
      if (_disposed || _currentState.runtimeType != stateType) return;
      final now = _clock.now();
      _timeline?.add(
        StateStuckEvent(
          source: name,
          timestamp: now,
          stuckState: stateType,
          maxDuration: maxDuration,
        ),
      );
      _safeReport(
        StuckStateViolation(
          source: name,
          timestamp: now,
          reason: 'Fence "$name" has been in state $stateType for longer '
              'than $maxDuration.',
          stuckState: stateType,
          maxDuration: maxDuration,
        ),
      );
    });
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
  /// Cancels any pending stuck-state timer. Subsequent transition attempts
  /// report a [UseAfterDisposeViolation] and are rejected.
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _stuckTimer?.cancel();
    _stuckTimer = null;
    _timeline?.add(
      OwnerDisposedEvent(
        source: name,
        timestamp: _clock.now(),
      ),
    );
  }
}
