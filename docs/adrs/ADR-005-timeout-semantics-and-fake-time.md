# ADR-005: Timeout semantics and fake time

## Status

Accepted

## Context

Stuck-state detection must be testable without waiting for real wall-clock time. The package needs a clock and a scheduler abstraction.

## Decision

Introduce `FenceClock` and `FenceScheduler` interfaces. The default implementation uses `DateTime.now()` and real timers. Tests provide fake implementations that can advance time and trigger scheduled callbacks deterministically.

## Consequences

- Timeout tests are fast and deterministic.
- Real and fake clocks are interchangeable at construction time.
- The core package does not depend on `package:fake_async` or similar heavy test-only dependencies.
