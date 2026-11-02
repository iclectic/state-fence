import 'package:bloc/bloc.dart';
import 'package:state_fence/state_fence.dart';

/// A [Cubit] that emits only when its [StateFence] accepts the transition.
///
/// The fence is created with the cubit and disposed when [close] runs. A
/// rejected transition leaves the emitted state unchanged.
class StateFenceCubit<S> extends Cubit<S> {
  /// Creates a cubit and the fence that guards it.
  ///
  /// [name], [initialState] and [rules] are forwarded to [StateFence]. The
  /// remaining arguments are the same injectable clock, scheduler, reporter
  /// and timeline the core accepts.
  StateFenceCubit({
    required String name,
    required S initialState,
    required List<TransitionRule> rules,
    StateFenceReporter? reporter,
    bool captureStackTrace = false,
    FenceClock? clock,
    FenceScheduler? scheduler,
    Timeline? timeline,
    Map<Type, Duration> stuckStateTimeouts = const <Type, Duration>{},
  })  : fence = StateFence<S>(
          name: name,
          initialState: initialState,
          rules: rules,
          reporter: reporter,
          captureStackTrace: captureStackTrace,
          clock: clock,
          scheduler: scheduler,
          timeline: timeline,
          stuckStateTimeouts: stuckStateTimeouts,
        ),
        super(initialState);

  /// The fence that decides whether [transition] may emit.
  final StateFence<S> fence;

  /// Attempts [next]. Emits [next] only when the fence accepts it.
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
      emit(result.state);
    }
    return result;
  }

  /// Disposes [fence], then closes the cubit.
  @override
  Future<void> close() {
    fence.dispose();
    return super.close();
  }
}
