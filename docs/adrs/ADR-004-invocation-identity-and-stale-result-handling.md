# ADR-004: Invocation identity and stale-result handling

## Status

Proposed

## Context

Guarded operations must be able to identify which async invocation produced a result. This identity is necessary to discard results from older invocations when a newer one has already been accepted.

## Proposed Decision

Each `GuardedOperation.run()` call generates an `OperationToken`. The token is a monotonic, unique identifier produced by an injectable token generator. The operation accepts only the result whose token matches the newest accepted token. Results from older tokens produce `OperationIgnoredAsStale`.

## Consequences

- Tests can provide a deterministic token generator.
- Race-condition invariants can be asserted without real delays.
- Token generation is bounded only by the integer width used by the generator.
