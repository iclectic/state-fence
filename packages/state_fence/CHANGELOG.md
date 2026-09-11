# Changelog

All notable changes to `state_fence` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.1.0

### Added

- `StateFence<S>` with typed transition contracts and `allow<F, T>()` rule syntax.
- `TransitionResult<S>` sealed hierarchy: `TransitionAccepted<S>` and `TransitionRejected<S>`.
- `StateFenceViolation` sealed hierarchy: `TransitionViolation`, `OperationTimeoutViolation`, `StuckStateViolation` and `UseAfterDisposeViolation`, each with source, timestamp, operation, safe metadata, stack trace and reason.
- `StateFenceReporter` interface and `DevNullReporter` default. Throwing reporters enable strict mode at synchronous call sites; timeline events are always recorded before the reporter is invoked.
- `GuardedOperation<T>` with `OperationPolicy.latestWins` and `OperationPolicy.firstWins`.
- `OperationOutcome<T>` sealed hierarchy: `OperationSuccess`, `OperationFailure`, `OperationIgnoredAsStale`, `OperationIgnoredAsDuplicate` and `OperationTimedOut`.
- Timeouts resolve the `run` future with `OperationTimedOut` as soon as they fire, so callers are never left waiting on a stuck operation. Late results are discarded. Under `firstWins`, a timed-out invocation no longer blocks a retry.
- Stuck-state detection on `StateFence` via `stuckStateTimeouts`, reporting `StuckStateViolation` and recording `StateStuckEvent` when a transitional state exceeds its declared maximum duration.
- `StateFence.wouldAllow` and `StateFence.canTransitionTo` for querying rules without transitioning.
- `Disposable` interface implemented by `StateFence` and `GuardedOperation` for uniform lifecycle ownership.
- `OperationToken` and `OperationTokenGenerator` for injectable invocation identity.
- `FenceClock`, `RealFenceClock` and `FenceSchedulerClock` for deterministic time. Both `StateFence` and `GuardedOperation` accept a `clock`, defaulting to the supplied `scheduler` when one is given.
- `FenceScheduler`, `RealFenceScheduler` and `FakeFenceScheduler` for deterministic timeouts. `FakeFenceScheduler.elapse` fires timers in chronological order even when a callback schedules or cancels further timers, and never moves its clock backwards.
- `FenceEvent` sealed hierarchy with ten event types for transition, operation and stuck-state diagnostics.
- `Timeline` bounded ring buffer with configurable capacity, dropped count and filtering by source or event type.
- `MetadataRedactor` with default sensitive key redaction, custom callback support and recursive redaction. A sensitive key redacts its entire subtree, including nested maps and lists. Redaction is total: maps with non-`String` keys are stringified, non-`List` iterables are converted to lists, and recursion is bounded by `maxDepth` so cyclic or pathologically nested metadata is truncated rather than crashing or hanging.
- `exportTimelineJson` producing an envelope with `droppedCount` and redacted `events`. Metadata values that JSON cannot represent natively, such as `DateTime`, are encoded with `toString` so a diagnostic export never throws.
- `StateFence.dispose()` and `GuardedOperation.dispose()` with `UseAfterDisposeViolation` reporting.
- Unit tests covering transitions, race conditions, timeouts, retry-after-timeout, disposal, stuck states, ring-buffer overflow, subtree redaction and throwing reporters.
