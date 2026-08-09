# Changelog

All notable changes to `state_fence` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.1.0

### Added

- `StateFence<S>` with typed transition contracts and `allow<F, T>()` rule syntax.
- `TransitionResult<S>` sealed hierarchy: `TransitionAccepted<S>` and `TransitionRejected<S>`.
- `StateFenceViolation` structured violation model with fence name, state types, timestamp, operation, safe metadata, stack trace and reason.
- `StateFenceReporter` interface and `DevNullReporter` default.
- `GuardedOperation<T>` with `OperationPolicy.latestWins` and `OperationPolicy.firstWins`.
- `OperationOutcome<T>` sealed hierarchy: `OperationSuccess`, `OperationFailure`, `OperationIgnoredAsStale`, `OperationIgnoredAsDuplicate`.
- `OperationToken` and `OperationTokenGenerator` for injectable invocation identity.
- `FenceClock`, `RealFenceClock` and `FenceSchedulerClock` for deterministic time.
- `FenceScheduler`, `RealFenceScheduler` and `FakeFenceScheduler` for deterministic timeouts.
- `FenceEvent` sealed hierarchy with nine event types for transition and operation lifecycle diagnostics.
- `Timeline` bounded ring buffer with configurable capacity and dropped count.
- `MetadataRedactor` with default sensitive key redaction, custom callback support and recursive nested map and list redaction.
- `exportTimelineJson` for JSON serialisation with redaction.
- Reporter failure isolation: throwing reporters do not prevent timeline recording.
- `StateFence.dispose()` and `GuardedOperation.dispose()` with post-dispose violation reporting.
- 36 unit tests covering transitions, race conditions, timeouts, disposal, ring-buffer overflow, nested redaction and reporter isolation.
