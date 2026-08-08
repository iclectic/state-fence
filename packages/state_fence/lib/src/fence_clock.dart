import 'package:meta/meta.dart';

import 'fence_scheduler.dart';

/// A clock abstraction for deterministic time in [StateFence] and
/// [GuardedOperation].
///
/// The default [RealFenceClock] uses [DateTime.now]. Tests can supply a fake
/// implementation or reuse a [FakeFenceScheduler] via [FenceSchedulerClock].
abstract interface class FenceClock {
  /// The current time according to this clock.
  DateTime now();
}

/// A [FenceClock] backed by real wall-clock time.
final class RealFenceClock implements FenceClock {
  /// Creates a real clock.
  const RealFenceClock();

  @override
  DateTime now() => DateTime.now();
}

/// A [FenceClock] that delegates to a [FenceScheduler]'s [now] method.
@immutable
final class FenceSchedulerClock implements FenceClock {
  /// The scheduler to read time from.
  final FenceScheduler scheduler;

  /// Creates a clock backed by [scheduler].
  const FenceSchedulerClock(this.scheduler);

  @override
  DateTime now() => scheduler.now();
}
