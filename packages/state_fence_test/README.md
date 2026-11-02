# state_fence_test

Test utilities and matchers for `state_fence`.

This package provides:

- Transition matchers: `allowsTransition<F, T>()` and `rejectsTransition<F, T>()`.
- Outcome matchers: `isOperationSuccess()`, `isOperationFailure`, `isIgnoredAsStale`, `isIgnoredAsDuplicate` and `isOperationTimedOut`.
- `CollectingReporter` for asserting on violations.
- `ThrowingReporter` for tests where any violation should fail immediately.
- Re-exports of `FakeFenceScheduler`, `FenceSchedulerClock` and `MonotonicTokenGenerator`.

## Install

```yaml
dev_dependencies:
  state_fence_test: ^0.1.0
```

Use that coordinate once the package is published. `state_fence_test` depends on `state_fence`. In the StateFence repository, `pubspec_overrides.yaml` resolves the core from the sibling package. That file is excluded from the published archive.

## Matchers

The sample below is the same shape as `example/state_fence_test_example.dart`. `allowsTransition` reads the fence rules. `isIgnoredAsStale` matches a `latestWins` result that lost to a newer invocation. `FakeFenceScheduler.elapse` fires the timeout without `Future.delayed`.

```dart
import 'dart:async';

import 'package:state_fence/state_fence.dart';
import 'package:state_fence_test/state_fence_test.dart';
import 'package:test/test.dart';

sealed class SearchState {
  const SearchState();
}

final class Idle extends SearchState {
  const Idle();
}

final class Loading extends SearchState {
  const Loading();
}

void main() {
  test('declares the expected transition', () {
    final fence = StateFence<SearchState>(
      name: 'search',
      initialState: const Idle(),
      rules: [allow<Idle, Loading>()],
    );

    expect(fence, allowsTransition<Idle, Loading>());
  });

  test('latestWins discards the slower result', () async {
    final older = Completer<int>();
    final newer = Completer<int>();
    final search = GuardedOperation<int>(
      name: 'search',
      policy: OperationPolicy.latestWins,
    );

    final olderFuture = search.run(() => older.future);
    final newerFuture = search.run(() => newer.future);

    newer.complete(2);
    older.complete(1);

    expect(await newerFuture, isOperationSuccess(value: 2));
    expect(await olderFuture, isIgnoredAsStale);
  });

  test('timeouts resolve on a fake scheduler', () async {
    final scheduler = FakeFenceScheduler();
    final search = GuardedOperation<int>(
      name: 'search',
      policy: OperationPolicy.latestWins,
      timeout: const Duration(seconds: 5),
      scheduler: scheduler,
    );

    final future = search.run(() => Completer<int>().future);
    scheduler.elapse(const Duration(seconds: 5));

    expect(await future, isOperationTimedOut);
  });
}
```

Run the checked-in example with `dart test example/state_fence_test_example.dart`.

## Licence

MIT. See `LICENSE`.
