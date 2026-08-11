# StateFence

Catch dangerous state transitions before your users do.

StateFence is a state-management-neutral correctness toolkit for Dart and Flutter. It validates state transitions, guards asynchronous operations against race conditions and records privacy-aware diagnostics. It does not replace your existing state-management solution; it sits beside it.

## 30-Second Stale Response Example

```dart
import 'package:state_fence/state_fence.dart';

final search = GuardedOperation<List<String>>(
  name: 'search',
  policy: OperationPolicy.latestWins,
);

// User types "a", then "ab", then "abc".
final slowFuture = search.run(() => repository.search('a'));   // slow
final fastFuture = search.run(() => repository.search('abc')); // fast

// "abc" returns first and is accepted.
final fastOutcome = await fastFuture;
if (fastOutcome case OperationSuccess(:final value)) {
  emit(SearchState.data(value));
}

// "a" returns later and is discarded as stale.
final slowOutcome = await slowFuture;
// slowOutcome is OperationIgnoredAsStale
```

Without `latestWins`, the slow "a" response would overwrite the newer "abc" results. StateFence prevents that silently.

## Installation

Add StateFence to your `pubspec.yaml`:

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

## Guarded Operations

Run async work with a concurrency policy so stale or duplicate results cannot silently overwrite newer state.

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

The default `MetadataRedactor` redacts keys such as `password`, `token`, `secret`, `authorisation`, `authorization`, `cookie`, `api_key`, `apikey`, `access_token` and `refresh_token`. Matching is case-insensitive and recursive through nested maps and lists.

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

### ChangeNotifier or Provider

Hold a `StateFence` in your notifier. Call `transition` in each method that changes state. Notify listeners only on accepted transitions.

### Riverpod

Use a `StateNotifier` or `Notifier` that holds a `StateFence`. Call `transition` before assigning to `state`. Use `GuardedOperation` inside `AsyncNotifier` to protect against stale async results.

### BLoC or Cubit

Hold a `StateFence` in your bloc. Call `transition` in each event handler before emitting a new state. Use `GuardedOperation` for async event handlers that produce state.

### Search-as-you-type

Use `OperationPolicy.latestWins` so only the newest query's results are accepted. Discard older results automatically.

### Save or payment submission

Use `OperationPolicy.firstWins` so repeated taps are ignored while the first request is in flight.

### Pull-to-refresh

Use `GuardedOperation` with a `timeout` so a stuck refresh call resolves with `OperationTimedOut` instead of an infinite spinner. Pair it with `stuckStateTimeouts` on the fence to catch stuck states that bypass the operation layer.

## Limitations and Non-Goals

- StateFence does not replace `Riverpod`, `BLoC`, `Provider`, `ChangeNotifier` or `setState`.
- StateFence does not provide production application-performance monitoring, network inspection or general logging.
- StateFence is not a replacement for Flutter DevTools.
- `restartable`, `sequential` and `parallel` operation policies are planned for v0.2.0.
- Retry policies with exponential backoff are planned for v0.2.0.
- Riverpod and BLoC adapter packages are planned for v0.2.0.
- An in-app inspector is planned for v0.3.0.
- Dart futures are not cancelable. A timeout resolves the outcome immediately and discards the late result, but the underlying work continues until it settles on its own.
- `allow<F, T>()` does not enforce the state-domain bound at compile time. Rules are checked at transition time by runtime type.

## Packages

| Package | Description |
|---------|-------------|
| `state_fence` | Pure Dart core. Transition rules, guarded operations, stuck-state detection, diagnostics and redaction. |
| `state_fence_flutter` | Flutter integration. Lifecycle ownership and `FlutterErrorReporter`. |
| `state_fence_test` | Matchers, `CollectingReporter`, `ThrowingReporter` and deterministic fakes. |

## Contribution and Support Policy

Contributions are welcome. Please read `CONTRIBUTING.md` and `CODE_OF_CONDUCT.md` before opening a pull request. All public APIs must be documented with `dartdoc`, and `dart format`, `dart analyze` and tests must pass.

For security issues, see `SECURITY.md`.

## Licence

MIT. See `LICENSE`.
