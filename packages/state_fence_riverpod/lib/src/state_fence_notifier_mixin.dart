import 'package:riverpod/riverpod.dart';
import 'package:state_fence/state_fence.dart';

/// Adds a [StateFence] to a Riverpod [Notifier].
///
/// Call [attachFence] from `build`. The fence is disposed with the provider.
/// [transition] assigns `state` only when the fence accepts the next value.
mixin StateFenceNotifierMixin<S> on Notifier<S> {
  StateFence<S>? _fence;

  /// The fence created by [attachFence].
  ///
  /// Throws [StateError] when read before [attachFence].
  StateFence<S> get fence {
    final StateFence<S>? current = _fence;
    if (current == null) {
      throw StateError(
        'Call attachFence from build before reading fence.',
      );
    }
    return current;
  }

  /// Creates the fence and disposes it when this provider is disposed.
  ///
  /// Must be called from `build`, where `ref` can register a dispose callback.
  /// A later call replaces the previous fence and disposes it.
  StateFence<S> attachFence({
    required String name,
    required S initialState,
    required List<TransitionRule> rules,
    StateFenceReporter? reporter,
    bool captureStackTrace = false,
    FenceClock? clock,
    FenceScheduler? scheduler,
    Timeline? timeline,
    Map<Type, Duration> stuckStateTimeouts = const <Type, Duration>{},
  }) {
    final StateFence<S> created = StateFence<S>(
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
    final StateFence<S>? previous = _fence;
    _fence = created;
    ref.onDispose(() {
      created.dispose();
      if (identical(_fence, created)) {
        _fence = null;
      }
    });
    previous?.dispose();
    return created;
  }

  /// Attempts [next]. Assigns `state` only when the fence accepts it.
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
      state = result.state;
    }
    return result;
  }
}
