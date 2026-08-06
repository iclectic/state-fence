# ADR-007: Debug, profile and release behaviour

## Status

Proposed

## Context

The package must behave safely in release builds while remaining useful in development. Reporting, stack traces and assertion-like behaviour need different defaults per build mode.

## Proposed Decision

- Development defaults: report violations through the injectable reporter, optionally capture stack traces, record events in the timeline.
- Profile defaults: reporter continues to record, but stack trace capture is disabled unless configured.
- Release defaults: no automatic reporting unless the user explicitly installs a reporter and opts into timeline capture. Strict throw mode must be opt-in in release.
- Build mode detection, if needed, is performed by the consumer or by `state_fence_flutter`. The core package does not import `dart:developer` or `Flutter` for mode detection.

## Consequences

- No runtime overhead in release unless the user enables diagnostics.
- Consumers choose how to surface violations in their reporting infrastructure.
- The core package remains build-mode agnostic.
