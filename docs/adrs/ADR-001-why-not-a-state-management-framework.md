# ADR-001: Why StateFence is not a state-management framework

## Status

Accepted

## Context

The Flutter ecosystem already contains `Riverpod`, `BLoC`, `Provider`, `ChangeNotifier`, `setState` and many other ways to hold and emit state. A new package that also claims to own state would compete for the same integration points and would have to re-implement bindings for every framework.

## Decision

StateFence will be a state-management-neutral correctness toolkit. It validates state transitions, guards asynchronous operations and records diagnostics. It will not own the state object, emit rebuilds or require a specific state-management pattern.

## Consequences

- Users can adopt StateFence incrementally in an existing project without a migration.
- The package has a smaller, more focused public API.
- The core package can remain pure Dart.
- Adapter packages can be added later as thin wrappers.
- StateFence must expose deterministic, framework-agnostic primitives that users wire into their chosen state-management solution.
