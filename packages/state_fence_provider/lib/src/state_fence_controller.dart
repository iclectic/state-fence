import 'package:flutter/foundation.dart';
import 'package:state_fence/state_fence.dart';

/// A [ChangeNotifier] that notifies listeners only when a [StateFence]
/// accepts the transition.
///
/// The fence is created with the controller and disposed from [dispose].
class StateFenceController<S> extends ChangeNotifier {
  /// Creates a controller and the fence that guards it.
  StateFenceController({
    required String name,
    required S initialState,
    required List<TransitionRule> rules,
    StateFenceReporter? reporter,
    bool captureStackTrace = false,
    FenceClock? clock,
    FenceScheduler? scheduler,
    Timeline? timeline,
    Map<Type, Duration> stuckStateTimeouts = const <Type, Duration>{},
  }) : fence = StateFence<S>(
          name: name,
          initialState: initialState,
          rules: rules,
          reporter: reporter,
          captureStackTrace: captureStackTrace,
          clock: clock,
          scheduler: scheduler,
          timeline: timeline,
          stuckStateTimeouts: stuckStateTimeouts,
        );

  /// The fence that decides whether [transition] may notify listeners.
  final StateFence<S> fence;

  /// The fence's current state.
  S get state => fence.current;

  /// Attempts [next]. Notifies listeners only when the fence accepts it.
  TransitionResult<S> transition(
    S next, {
    String? operation,
    Map<String, Object?>? metadata,
  }) {
    final TransitionResult<S> result = fence.transition(
      next,
      operation: operation,
      metadata: metadata,
    );
    if (result is TransitionAccepted<S>) {
      notifyListeners();
    }
    return result;
  }

  /// Disposes [fence], then the notifier.
  @override
  void dispose() {
    fence.dispose();
    super.dispose();
  }
}
