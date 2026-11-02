# state_fence

Catch dangerous state transitions before your users do.

`state_fence` is a state-management-neutral correctness toolkit for Dart. It checks transitions, guards asynchronous work against stale and duplicate results, and records a redacted diagnostic timeline. It does not replace `setState`, `ChangeNotifier`, Provider, Riverpod or BLoC, and it does not rebuild widgets.

Flutter lifecycle helpers are in `state_fence_flutter`. Matchers and `FakeFenceScheduler` are in `state_fence_test`.

## Install

```yaml
dependencies:
  state_fence: ^0.1.0
```

That is the consumer coordinate for the published package. In the StateFence repository, sibling packages resolve this core through `pubspec_overrides.yaml` so a clone can be tested before publication. That override file is not part of this archive.

## Apply guarded outcomes through the fence

The same flow is `example/state_fence_example.dart`. It declares a sealed state and an `allow` list, runs the async work in a `GuardedOperation`, and calls `StateFence.transition` only for `OperationSuccess`, `OperationFailure` and `OperationTimedOut`. `OperationIgnoredAsStale` and `OperationIgnoredAsDuplicate` leave `ui` unchanged. `ui` is assigned only when the result is `TransitionAccepted`.

`pay` uses `firstWins`, so a second tap while the first is in flight is a duplicate. `quote` uses `latestWins`, so the slower result is stale. The `pay` timeout resolves as `OperationTimedOut` instead of hanging. `stuckStateTimeouts` records a `StateStuckEvent` if `Submitting` stays current too long. `exportTimelineJson` redacts the `token` metadata key.

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

final class Failed extends CheckoutState {
  const Failed(this.message);
  final String message;
}

Future<void> main() async {
  final timeline = Timeline(capacity: 64);
  final fence = StateFence<CheckoutState>(
    name: 'checkout',
    initialState: const Idle(),
    rules: [
      allow<Idle, Submitting>(),
      allow<Submitting, Paid>(),
      allow<Submitting, Failed>(),
      allow<Failed, Submitting>(),
    ],
    timeline: timeline,
    stuckStateTimeouts: const {
      Submitting: Duration(milliseconds: 100),
    },
  );
  final pay = GuardedOperation<String>(
    name: 'pay',
    policy: OperationPolicy.firstWins,
    timeout: const Duration(milliseconds: 40),
    timeline: timeline,
  );
  final quote = GuardedOperation<String>(
    name: 'quote',
    policy: OperationPolicy.latestWins,
    timeline: timeline,
  );

  CheckoutState ui = const Idle();

  String describe(CheckoutState state) => switch (state) {
        Idle() => 'Idle',
        Submitting() => 'Submitting',
        Paid(:final receipt) => 'Paid($receipt)',
        Failed(:final message) => 'Failed($message)',
      };

  CheckoutState apply(TransitionResult<CheckoutState> result) {
    switch (result) {
      case TransitionAccepted(:final state):
        print('Accepted. UI is now ${describe(state)}.');
        return state;
      case TransitionRejected(:final violation):
        print('Rejected: ${violation.reason}');
        print('UI unchanged: ${describe(ui)}.');
        return ui;
    }
  }

  CheckoutState applyOutcome(OperationOutcome<String> outcome) {
    switch (outcome) {
      case OperationSuccess(:final value):
        return apply(
          fence.transition(
            Paid(value),
            operation: 'pay',
            metadata: const <String, Object?>{
              'token': 'card-token-secret',
              'amount': '42.00',
            },
          ),
        );
      case OperationFailure(:final error):
        return apply(fence.transition(Failed('$error'), operation: 'pay'));
      case OperationTimedOut(:final timeout):
        print('Timed out after $timeout. The future is not cancelled.');
        return apply(
          fence.transition(
            Failed('Timed out after $timeout.'),
            operation: 'pay',
          ),
        );
      case OperationIgnoredAsStale():
        print('Ignored as stale. UI stays ${describe(ui)}.');
        return ui;
      case OperationIgnoredAsDuplicate():
        print('Ignored as duplicate. UI stays ${describe(ui)}.');
        return ui;
    }
  }

  print('1. Reject a jump from idle to paid.');
  ui = apply(fence.transition(const Paid('skipped'), operation: 'pay'));

  print('2. Enter submitting and wait for the stuck-state timeout.');
  ui = apply(fence.transition(const Submitting(), operation: 'pay'));
  await Future<void>.delayed(const Duration(milliseconds: 150));
  for (final event in timeline.events.whereType<StateStuckEvent>()) {
    print('Stuck: ${event.stuckState} exceeded ${event.maxDuration}.');
  }

  print('3. Fail the payment. A second tap is a duplicate.');
  final failing = pay.run(() async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    throw StateError('card declined');
  });
  ui = applyOutcome(await pay.run(() async => 'second tap'));
  ui = applyOutcome(await failing);

  print('4. Time out a payment that never completes.');
  ui = apply(fence.transition(const Submitting(), operation: 'pay'));
  ui = applyOutcome(await pay.run(() => Completer<String>().future));

  print('5. Accept the fast quote and ignore the slow one.');
  ui = apply(fence.transition(const Submitting(), operation: 'pay'));
  final slow = quote.run(() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return 'slow-receipt';
  });
  final fast = quote.run(() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return 'fast-receipt';
  });
  ui = applyOutcome(await fast);
  ui = applyOutcome(await slow);
  print('Final UI: ${describe(ui)}');

  print(exportTimelineJson(timeline));
}
```

`allow<F, T>()` does not enforce the state-domain bound at compile time. Rules are checked at transition time by runtime type.

Run it from this package with `dart run example/state_fence_example.dart`. The checked-in example also stops if a step does not produce the expected state.

## Policies

`OperationPolicy.latestWins` accepts only the newest invocation. Older in-flight results complete as `OperationIgnoredAsStale` when they settle. Use it for search-as-you-type.

`OperationPolicy.firstWins` ignores a new invocation while one is already in flight, and completes it as `OperationIgnoredAsDuplicate`. Use it for save and payment buttons. After a timeout, that invocation no longer blocks a new run.

`OperationPolicy.restartable` matches `latestWins`, and it also completes the previous future as `OperationIgnoredAsStale` as soon as a newer run starts. The previous action is not cancelled.

`OperationPolicy.sequential` runs calls one at a time, in the order they were started. A later call waits until the earlier one has been accepted, has failed or has timed out. Queued calls are not duplicates.

`OperationPolicy.parallel` accepts every invocation, including ones that overlap. Each call still has its own timeout.

## Retry

Pass a `RetryPolicy` to `GuardedOperation` to rerun the action after a thrown failure. `maxAttempts` includes the first run. Delays grow from `initialDelay` by `multiplier` and stop at `maxDelay`. The delay uses the same `FenceScheduler` as timeouts, so tests advance it with `FakeFenceScheduler.elapse`. Timeouts, stale results and duplicates are not retried. This is not a data client.

## Timeouts

When `timeout` is set, `run` completes with `OperationTimedOut` as soon as the duration elapses. The caller is not left waiting. A result that arrives later is discarded.

## Stuck states

`stuckStateTimeouts` maps a state type to a maximum duration. If the fence is still in that state when the duration elapses, it reports a `StuckStateViolation` and records a `StateStuckEvent`. The injectable `FenceScheduler` drives the timer, so tests can advance fake time instead of waiting.

## Redacted export

Attach a `Timeline` to the fence and the operation, then call `exportTimelineJson`. The default `MetadataRedactor` replaces values whose keys match a fixed set of sensitive names, including `password`, `token`, `secret`, `authorisation`, `authorization`, `cookie`, `api_key`, `apikey`, `access_token` and `refresh_token`. Matching is case-insensitive and applies to nested maps and lists.

## Limits

- The default reporter is `DevNullReporter`. It is silent. Pass a reporter when you also want violations surfaced. `state_fence_flutter` provides `FlutterErrorReporter` and `stateFenceReporterForBuildMode`, which reports in debug and profile and stays silent in release. `state_fence_test` provides `CollectingReporter` and `ThrowingReporter`.
- A thrown error is recorded on the timeline as its runtime type. The exception message is not stored, and `exportTimelineJson` does not add it. Pass `errorDescriber: describeErrorMessage` on `GuardedOperation` only when that message is safe to keep. The outcome returned to the caller still carries the error object.
- A timeout does not cancel the future. Dart futures are not cancellable. The late result is ignored.
- The fence does not rebuild widgets. Update your own state holder only from `TransitionAccepted`.

## Licence

MIT. See `LICENSE`.
