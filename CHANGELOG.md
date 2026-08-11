# Changelog

All notable changes to the StateFence packages are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.1.0

### Added

#### state_fence

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
- `FenceClock`, `RealFenceClock` and `FenceSchedulerClock` for deterministic time.
- `FenceScheduler`, `RealFenceScheduler` and `FakeFenceScheduler` for deterministic timeouts.
- `FenceEvent` sealed hierarchy with ten event types for transition, operation and stuck-state diagnostics.
- `Timeline` bounded ring buffer with configurable capacity, dropped count and filtering by source or event type.
- `MetadataRedactor` with default sensitive key redaction, custom callback support and recursive redaction. A sensitive key redacts its entire subtree, including nested maps and lists.
- `exportTimelineJson` producing an envelope with `droppedCount` and redacted `events`.
- `StateFence.dispose()` and `GuardedOperation.dispose()` with `UseAfterDisposeViolation` reporting.
- Console example demonstrating transition contracts, stale-result discarding and non-hanging timeouts.

#### state_fence_flutter

- `StateFenceOwner` for explicit, type-safe lifecycle ownership of any `Disposable` resource.
- `StateFenceStateMixin` for automatic disposal on `State.dispose`.
- `FlutterErrorReporter` forwarding violations to `FlutterError.reportError` with per-violation diagnostic properties.
- `StateFenceViolationException` wrapping violations for Flutter's error pipeline.
- Example application with three failure scenarios: stale search, duplicate submission and stuck loading.

#### state_fence_test

- Transition matchers: `allowsTransition<F, T>()` and `rejectsTransition<F, T>()`.
- Outcome matchers: `isOperationSuccess()`, `isOperationFailure`, `isIgnoredAsStale`, `isIgnoredAsDuplicate` and `isOperationTimedOut`.
- `CollectingReporter` with type filtering and `hasViolations`.
- `ThrowingReporter` for strict tests.
- `hasNoViolations` matcher.
- Re-exports of `FakeFenceScheduler`, `FenceSchedulerClock` and `MonotonicTokenGenerator`.

### Changed

- Updated `README.md` with quick start, concepts, recipes, limitations and migration policy.
- Updated `AGENTS.md` with repository layout, commands and definition of done.
- Strict analysis options (`strict-casts`, `strict-inference`, `strict-raw-types`) applied to all packages.

## 0.1.0-dev

- Repository foundation.
- Product brief, ecosystem review and provisional API proposal.
- Architecture decision record stubs.
- Scaffolding for `state_fence`, `state_fence_flutter` and `state_fence_test`.
- Strict analysis options and CI workflow.
