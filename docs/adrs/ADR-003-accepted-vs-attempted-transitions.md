# ADR-003: Accepted versus attempted transitions

## Status

Accepted

## Context

A state fence must decide whether a requested transition is allowed. The public API must expose both the accepted state and a structured record of any rejection.

## Decision

A `transition` call returns a `TransitionResult` with two subtypes: `TransitionAccepted` and `TransitionRejected`. The rejected result contains a `StateFenceViolation` with fence name, previous state, attempted state, timestamp, operation identifier, safe metadata, stack trace and human-readable reason.

## Consequences

- Callers must handle both outcomes explicitly.
- Violations are first-class values, not only log messages or thrown exceptions.
- Strict mode can be enabled by a reporter that throws on report.
