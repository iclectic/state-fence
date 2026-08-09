# state_fence

Catch dangerous state transitions before your users do.

StateFence is a state-management-neutral correctness toolkit for Dart and Flutter. This is the pure Dart core package. It provides:

- Typed transition contracts with `allow<F, T>()` rule syntax.
- `GuardedOperation<T>` with `latestWins` and `firstWins` concurrency policies.
- Structured `StateFenceViolation` with injectable reporting.
- Bounded `Timeline` ring buffer with privacy-aware `MetadataRedactor` and JSON export.
- Injectable `FenceClock`, `FenceScheduler` and `OperationTokenGenerator` for deterministic tests.

This package has no Flutter dependency. For Flutter lifecycle integration, use `state_fence_flutter`.

## Quick Start

```dart
import 'package:state_fence/state_fence.dart';

final fence = StateFence<MyState>(
  name: 'checkout',
  initialState: const Idle(),
  rules: [
    allow<Idle, Submitting>(),
    allow<Submitting, Success>(),
    allow<Submitting, Failure>(),
    allow<Failure, Submitting>(),
  ],
);

final result = fence.transition(const Submitting());
if (result case TransitionRejected(:final violation)) {
  print(violation.reason);
}
```

See the [main README](../../README.md) for full documentation, recipes and limitations.
