# Changelog

All notable changes to `state_fence_test` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.1.0

### Added

- Transition matchers: `allowsTransition<F, T>()` and `rejectsTransition<F, T>()`.
- Outcome matchers: `isOperationSuccess()`, `isOperationFailure`, `isIgnoredAsStale`, `isIgnoredAsDuplicate` and `isOperationTimedOut`.
- `CollectingReporter` with type filtering and `hasViolations`.
- `ThrowingReporter` for strict tests.
- `hasNoViolations` matcher.
- Re-exports of `FakeFenceScheduler`, `FenceSchedulerClock` and `MonotonicTokenGenerator`.
