# state_fence_test

Test utilities and matchers for StateFence.

Provides:

- Transition matchers: `allowsTransition<F, T>()` and `rejectsTransition<F, T>()`.
- Outcome matchers: `isOperationSuccess()`, `isOperationFailure`, `isIgnoredAsStale`, `isIgnoredAsDuplicate` and `isOperationTimedOut`.
- `CollectingReporter` for asserting on violations, with type filtering.
- `ThrowingReporter` for strict tests where any violation should fail immediately.
- Re-exports of `FakeFenceScheduler`, `FenceSchedulerClock` and `MonotonicTokenGenerator` for deterministic time and identity.

## Quick Start

```dart
import 'dart:async';

import 'package:state_fence/state_fence.dart';
import 'package:state_fence_test/state_fence_test.dart';
import 'package:test/test.dart';

void main() {
  test('declares the expected transitions', () {
    final fence = StateFence<MyState>(
      name: 'checkout',
      initialState: const Idle(),
      rules: [allow<Idle, Submitting>()],
    );

    expect(fence, allowsTransition<Idle, Submitting>());
    expect(fence, rejectsTransition<Idle, Success>());
  });

  test('timeout resolves deterministically', () async {
    final scheduler = FakeFenceScheduler();
    final op = GuardedOperation<int>(
      name: 'op',
      policy: OperationPolicy.latestWins,
      timeout: const Duration(seconds: 5),
      scheduler: scheduler,
    );

    final future = op.run(() => Completer<int>().future);
    scheduler.elapse(const Duration(seconds: 5));

    expect(await future, isOperationTimedOut);
  });
}
```

See the [main README](../../README.md) for full documentation.
