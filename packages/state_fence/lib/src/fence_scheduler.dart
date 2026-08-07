import 'dart:async';

/// A timer abstraction used by [GuardedOperation] to enforce timeouts.
///
/// The default [RealFenceScheduler] uses [Timer] and [DateTime.now]. Tests
/// provide a fake implementation that can advance time deterministically.
abstract interface class FenceScheduler {
  /// The current time according to this scheduler.
  DateTime now();

  /// Starts a timer that calls [callback] after [duration].
  ///
  /// Returns a [FenceTimerHandle] that can be used to cancel the timer.
  FenceTimerHandle timer(Duration duration, void Function() callback);
}

/// A handle to a scheduled timer that can be cancelled.
abstract interface class FenceTimerHandle {
  /// Cancels the timer. Safe to call multiple times.
  void cancel();
}

/// A [FenceScheduler] backed by real wall-clock time and [Timer].
final class RealFenceScheduler implements FenceScheduler {
  /// Creates a real scheduler.
  const RealFenceScheduler();

  @override
  DateTime now() => DateTime.now();

  @override
  FenceTimerHandle timer(Duration duration, void Function() callback) =>
      _RealTimerHandle(Timer(duration, callback));
}

final class _RealTimerHandle implements FenceTimerHandle {
  final Timer _timer;
  bool _cancelled = false;

  _RealTimerHandle(this._timer);

  @override
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _timer.cancel();
  }
}

/// A deterministic [FenceScheduler] for tests.
///
/// Time does not advance automatically. Call [elapse] to move the clock
/// forward and fire any timers whose duration has elapsed, in chronological
/// order.
class FakeFenceScheduler implements FenceScheduler {
  DateTime _now;
  final List<_PendingTimer> _timers = [];

  /// Creates a fake scheduler starting at [initialTime].
  FakeFenceScheduler({DateTime? initialTime})
      : _now = initialTime ?? DateTime(2026, 1, 1);

  @override
  DateTime now() => _now;

  @override
  FenceTimerHandle timer(Duration duration, void Function() callback) {
    final pending = _PendingTimer(_now.add(duration), callback);
    _timers.add(pending);
    return pending;
  }

  /// Advances the clock by [duration] and fires any timers that have elapsed.
  void elapse(Duration duration) {
    final target = _now.add(duration);
    _timers.sort((a, b) => a.fireAt.compareTo(b.fireAt));
    while (_timers.isNotEmpty && _timers.first.fireAt.compareTo(target) <= 0) {
      final next = _timers.removeAt(0);
      if (next.isCancelled) continue;
      _now = next.fireAt;
      next.callback();
    }
    _now = target;
  }

  /// Whether any timers are currently pending and not cancelled.
  bool get hasPendingTimers => _timers.any((timer) => !timer.isCancelled);
}

final class _PendingTimer implements FenceTimerHandle {
  final DateTime fireAt;
  final void Function() callback;
  bool _cancelled = false;

  _PendingTimer(this.fireAt, this.callback);

  bool get isCancelled => _cancelled;

  @override
  void cancel() => _cancelled = true;
}
