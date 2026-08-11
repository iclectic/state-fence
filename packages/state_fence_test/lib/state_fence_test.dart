/// StateFence test utilities and matchers.
///
/// Provides readable matchers for transition contracts and operation
/// outcomes, a [CollectingReporter] for asserting on violations, and
/// re-exports the deterministic [FakeFenceScheduler] from the core package.
library;

export 'package:state_fence/state_fence.dart'
    show FakeFenceScheduler, FenceSchedulerClock, MonotonicTokenGenerator;

export 'src/collecting_reporter.dart';
export 'src/matchers.dart';
