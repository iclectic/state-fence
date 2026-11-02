# StateFence

Catch dangerous state transitions before your users do.

StateFence is a state-management-neutral correctness toolkit for Dart and Flutter. It validates state transitions, guards asynchronous operations against race conditions and records privacy-aware diagnostics. It does not replace your existing state-management solution; it sits beside it.

## 30-Second Stale Response Example

```dart
import 'dart:async';

import 'package:state_fence/state_fence.dart';

sealed class CheckoutState {
  const CheckoutState();
}

final class Idle extends CheckoutState {
  const Idle();
}

final class Submitting extends CheckoutState {
  const Submitting();
}

final class Paid extends CheckoutState {
  const Paid(this.receipt);
  final String receipt;
}

Future<void> main() async {
  final fence = StateFence<CheckoutState>(
    name: 'checkout',
    initialState: const Idle(),
    rules: [
      allow<Idle, Submitting>(),
      allow<Submitting, Paid>(),
    ],
  );
  final quote = GuardedOperation<String>(
    name: 'quote',
    policy: OperationPolicy.latestWins,
  );

  CheckoutState ui = const Idle();

  CheckoutState apply(TransitionResult<CheckoutState> result) {
    if (result case TransitionAccepted(:final state)) return state;
    return ui;
  }

  ui = apply(fence.transition(const Submitting()));

  final slow = quote.run(() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return 'slow-receipt';
  });
  final fast = quote.run(() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return 'fast-receipt';
  });

  switch (await fast) {
    case OperationSuccess(:final value):
      ui = apply(fence.transition(Paid(value)));
    case OperationFailure():
    case OperationTimedOut():
    case OperationIgnoredAsStale():
    case OperationIgnoredAsDuplicate():
      break;
  }

  switch (await slow) {
    case OperationIgnoredAsStale():
      print('Ignored as stale. UI stays $ui.');
    case OperationSuccess(:final value):
      ui = apply(fence.transition(Paid(value)));
    case OperationFailure():
    case OperationTimedOut():
    case OperationIgnoredAsDuplicate():
      break;
  }
}
```

`latestWins` completes the slower quote as `OperationIgnoredAsStale`. Apply `ui` only from `OperationSuccess` when the fence returns `TransitionAccepted`. Leave `ui` unchanged in the stale branch.

`allow<F, T>()` does not enforce the state-domain bound at compile time. Rules are checked at transition time by runtime type.

## Installation

```yaml
dependencies:
  state_fence: ^0.1.0
```

For Flutter lifecycle integration:

```yaml
dependencies:
  state_fence: ^0.1.0
  state_fence_flutter: ^0.1.0
```

For test utilities:

```yaml
dev_dependencies:
  state_fence_test: ^0.1.0
```

Optional adapters. Each one depends on the core. The core does not depend on them.

```yaml
dependencies:
  state_fence_bloc: ^0.1.0
  state_fence_riverpod: ^0.1.0
  state_fence_provider: ^0.1.0
```

## Working in this repository

Clone this repository and let `pubspec_overrides.yaml` resolve the sibling packages. Those override files are for local development. They are not part of a published archive.

From a clone:

```sh
cd packages/state_fence
dart pub get
dart test

cd ../state_fence_flutter/example
flutter pub get
flutter run
```

`packages/state_fence_flutter/pubspec_overrides.yaml` and `packages/state_fence_test/pubspec_overrides.yaml` point `state_fence` at the sibling core. The Flutter example override points both packages at this checkout.

## Transition Contracts

Declare which state-to-state movements are legal. Illegal transitions produce a structured violation and do not change the current state.

```dart
sealed class CheckoutState {
  const CheckoutState();
}

final class Idle extends CheckoutState { const Idle(); }
final class Submitting extends CheckoutState { const Submitting(); }
final class Success extends CheckoutState { const Success(); }
final class Failure extends CheckoutState {
  const Failure(this.message);
  final String message;
}

final fence = StateFence<CheckoutState>(
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

if (result case TransitionAccepted()) {
  // State is now Submitting.
} else if (result case TransitionRejected(:final violation)) {
  // An illegal transition was attempted.
  print(violation.reason);
}
```

Every fence and operation returns its result to the caller. Reporting is separate and opt in: the default reporter is silent, so pass a `reporter` such as `FlutterErrorReporter`, `CollectingReporter` or `ThrowingReporter` when you also want violations surfaced somewhere.

## Guarded Operations

Run async work with a concurrency policy so stale or duplicate results cannot silently overwrite newer state.

`OperationPolicy` also includes `restartable`, `sequential` and `parallel`, and a `GuardedOperation` can take a `RetryPolicy`. The `state_fence` README describes each of them.

### latestWins

Accepts only the newest invocation result. Older in-flight results are discarded as stale. Ideal for search-as-you-type.

```dart
final search = GuardedOperation<List<String>>(
  name: 'search',
  policy: OperationPolicy.latestWins,
  timeout: const Duration(seconds: 10),
);

final outcome = await search.run(() => repository.search(query));

if (outcome case OperationSuccess(:final value)) {
  emit(SearchState.data(value));
}
```

### firstWins

Ignores new invocations while one is already in flight. Ideal for save and payment buttons.

```dart
final pay = GuardedOperation<String>(
  name: 'pay',
  policy: OperationPolicy.firstWins,
);

final outcome = await pay.run(() => paymentService.charge());

if (outcome case OperationIgnoredAsDuplicate()) {
  // The user tapped twice; the second tap was ignored.
}
```

### Timeouts that never hang

When a `timeout` is configured, the `run` future resolves with `OperationTimedOut` as soon as the timeout fires. Callers are never left waiting on a stuck operation, and a late result is discarded automatically.

```dart
final refresh = GuardedOperation<Feed>(
  name: 'refresh',
  policy: OperationPolicy.latestWins,
  timeout: const Duration(seconds: 10),
);

final outcome = await refresh.run(() => repository.fetchFeed());

if (outcome case OperationTimedOut(:final timeout)) {
  emit(FeedState.error('Refresh timed out after $timeout.'));
}
```

Under `firstWins`, a timed-out invocation no longer blocks a retry.

## Stuck-State Detection

Declare a maximum duration for transitional states. If the fence stays in the state too long, a `StuckStateViolation` is reported and a `StateStuckEvent` is recorded.

```dart
final fence = StateFence<FeedState>(
  name: 'feed',
  initialState: const Idle(),
  rules: [...],
  stuckStateTimeouts: const {
    Loading: Duration(seconds: 15),
    Refreshing: Duration(seconds: 10),
  },
);
```

Detection is driven by the injectable `FenceScheduler`, so tests advance fake time instead of waiting.

## Diagnostic Events and Privacy

Attach a `Timeline` to record bounded diagnostic events. Export them as JSON with automatic redaction of sensitive values.

```dart
final timeline = Timeline(capacity: 256);

final fence = StateFence<MyState>(
  name: 'checkout',
  initialState: const Idle(),
  rules: [...],
  timeline: timeline,
);

final op = GuardedOperation<String>(
  name: 'pay',
  policy: OperationPolicy.firstWins,
  timeline: timeline,
);

// Later, export with redaction:
final json = exportTimelineJson(timeline);
// Sensitive keys like 'password', 'token', 'secret' are automatically
// replaced with '<redacted>'. Custom redactors are supported.
```

### Redaction

The default `MetadataRedactor` redacts keys such as `password`, `token`, `secret`, `authorisation`, `authorization`, `cookie`, `api_key`, `apikey`, `access_token` and `refresh_token`. Matching is case-insensitive and recursive through nested maps and iterables.

Redaction and export are total. Maps with non-`String` keys are stringified, recursion is bounded by `maxDepth` so cyclic metadata is truncated rather than looping, and values that JSON cannot represent natively are encoded with `toString`. Exporting diagnostics never throws because of the shape of the metadata you attached.

```dart
const redactor = MetadataRedactor(
  redactor: myCustomRedactor,
);

final json = exportTimelineJson(timeline, redactor: redactor);
```

## Flutter Lifecycle Integration

Use `StateFenceStateMixin` to automatically dispose fences and operations when a `State` is disposed.

```dart
class _CheckoutScreenState extends State<CheckoutScreen>
    with StateFenceStateMixin {
  late final fence = fenceOwner.register(
    StateFence<CheckoutState>(
      name: 'checkout',
      initialState: const Idle(),
      rules: [
        allow<Idle, Submitting>(),
        allow<Submitting, Success>(),
        allow<Submitting, Failure>(),
        allow<Failure, Submitting>(),
      ],
    ),
  );

  late final pay = fenceOwner.register(
    GuardedOperation<String>(
      name: 'pay',
      policy: OperationPolicy.firstWins,
    ),
  );

  // fenceOwner.dispose() is called automatically when the State is disposed.
}
```

### FlutterErrorReporter

Forward violations to Flutter's standard error pipeline:

```dart
final fence = StateFence<MyState>(
  name: 'my',
  initialState: const Idle(),
  rules: [...],
  reporter: const FlutterErrorReporter(),
);
```

## Testing

StateFence is designed for deterministic testing. The `state_fence_test` package provides readable matchers, a `CollectingReporter` and re-exports the deterministic `FakeFenceScheduler`.

```dart
import 'dart:async';

import 'package:state_fence/state_fence.dart';
import 'package:state_fence_test/state_fence_test.dart';
import 'package:test/test.dart';

void main() {
  test('declares the expected transitions', () {
    final fence = StateFence<MyState>(
      name: 'test',
      initialState: const Idle(),
      rules: [allow<Idle, Loading>()],
    );

    expect(fence, allowsTransition<Idle, Loading>());
    expect(fence, rejectsTransition<Success, Loading>());
  });

  test('rejects an illegal transition', () {
    final reporter = CollectingReporter();
    final fence = StateFence<MyState>(
      name: 'test',
      initialState: const Idle(),
      rules: [allow<Idle, Loading>()],
      reporter: reporter,
    );

    fence.transition(const Success());

    expect(reporter.violationsOfType<TransitionViolation>(), hasLength(1));
  });

  test('latestWins discards stale results', () async {
    final older = Completer<int>();
    final newer = Completer<int>();

    final op = GuardedOperation<int>(
      name: 'search',
      policy: OperationPolicy.latestWins,
    );

    final olderFuture = op.run(() => older.future);
    final newerFuture = op.run(() => newer.future);

    newer.complete(2);
    expect(await newerFuture, isOperationSuccess(value: 2));

    older.complete(1);
    expect(await olderFuture, isIgnoredAsStale);
  });

  test('timeout resolves via fake scheduler', () async {
    final scheduler = FakeFenceScheduler();
    final op = GuardedOperation<int>(
      name: 'search',
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

For strict tests where any violation should fail immediately, use `ThrowingReporter`: violations raised from synchronous call sites throw, and timeline events are always recorded before the reporter runs.

## State-Management Recipes

### setState

Call `fence.transition` before calling `setState`. Only update the UI when the transition is accepted.

### ChangeNotifier

Hold a `StateFence` in the notifier. Call `transition`, then `notifyListeners` only when the result is `TransitionAccepted`. The Flutter example does this in `packages/state_fence_flutter/example/lib/change_notifier_checkout.dart`.

### Provider

`state_fence_provider` provides `StateFenceController` and `stateFenceProvider`. Listeners are notified only when the fence accepts the transition.

### Riverpod

`state_fence_riverpod` provides `StateFenceNotifierMixin`. Call `attachFence` from `build`. `transition` assigns `state` only when the fence accepts it. The mixin targets Riverpod 2 `Notifier`.

### BLoC or Cubit

`state_fence_bloc` provides `StateFenceCubit`. `transition` emits only when the fence accepts, and `close` disposes the fence.

### Search-as-you-type

Use `OperationPolicy.latestWins` so only the newest query's results are accepted. Discard older results automatically.

### Save or payment submission

Use `OperationPolicy.firstWins` so repeated taps are ignored while the first request is in flight.

### Pull-to-refresh

Use `GuardedOperation` with a `timeout` so a stuck refresh call resolves with `OperationTimedOut` instead of an infinite spinner. Pair it with `stuckStateTimeouts` on the fence to catch stuck states that bypass the operation layer.

## Limitations and Non-Goals

- StateFence does not replace `Riverpod`, `BLoC`, `Provider`, `ChangeNotifier` or `setState`. Optional adapter packages sit beside an existing state holder. The core does not depend on those frameworks.
- StateFence does not provide production application-performance monitoring, network inspection or general logging. `StateFenceInspector` is an on-device view of a timeline you already hold.
- StateFence is not a replacement for Flutter DevTools.
- `RetryPolicy` reruns one action after a thrown failure. It does not retry a timeout, and it is not a data client.
- Dart futures are not cancelable. A timeout resolves the outcome immediately and discards the late result, but the underlying work continues until it settles on its own. `restartable` completes the previous future as stale immediately and still does not cancel the action.
- Conditional transition guards, and policies that carry their own configuration, are outside this release.

## Packages

| Package | Description |
|---------|-------------|
| `state_fence` | Pure Dart core. Transition rules, guarded operations, retry, stuck-state detection, diagnostics and redaction. |
| `state_fence_flutter` | Flutter integration. Lifecycle ownership, build-mode reporting and an opt-in inspector. |
| `state_fence_test` | Matchers, `CollectingReporter`, `ThrowingReporter` and deterministic fakes. |
| `state_fence_bloc` | `StateFenceCubit`. Emits only when the fence accepts the transition. |
| `state_fence_riverpod` | `StateFenceNotifierMixin` for a Riverpod 2 `Notifier`. |
| `state_fence_provider` | `StateFenceController` and `stateFenceProvider`. |

## Contribution and Support Policy

Contributions are welcome. Please read `CONTRIBUTING.md` and `CODE_OF_CONDUCT.md` before opening a pull request. All public APIs must be documented with `dartdoc`, and `dart format`, `dart analyze` and tests must pass.

For security issues, see `SECURITY.md`.

## Licence

MIT. See `LICENSE`.
