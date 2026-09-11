// Example: asserting on StateFence behaviour with state_fence_test.
//
// Run with: dart test example/state_fence_test_example.dart
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

final class Data extends SearchState {
  const Data();
}

StateFence<SearchState> buildFence({StateFenceReporter? reporter}) {
  return StateFence<SearchState>(
    name: 'search',
    initialState: const Idle(),
    rules: [
      allow<Idle, Loading>(),
      allow<Loading, Data>(),
    ],
    reporter: reporter,
  );
}

void main() {
  test('transition matchers describe the contract', () {
    final fence = buildFence();

    expect(fence, allowsTransition<Idle, Loading>());
    expect(fence, rejectsTransition<Idle, Data>());
  });

  test('CollectingReporter captures illegal transitions', () {
    final reporter = CollectingReporter();
    final fence = buildFence(reporter: reporter);

    // Idle -> Data is not a declared rule, so the transition is reported.
    fence.transition(const Data());

    expect(reporter.hasViolations, isTrue);
    expect(reporter.violationsOfType<TransitionViolation>(), hasLength(1));
  });

  test('outcome matchers read guarded operation results', () async {
    final op = GuardedOperation<int>(
      name: 'load',
      policy: OperationPolicy.latestWins,
    );

    expect(await op.run(() async => 42), isOperationSuccess(value: 42));
  });

  test('FakeFenceScheduler drives timeouts without real waiting', () async {
    final scheduler = FakeFenceScheduler();
    final op = GuardedOperation<int>(
      name: 'load',
      policy: OperationPolicy.latestWins,
      timeout: const Duration(seconds: 5),
      scheduler: scheduler,
    );

    final future = op.run(() => Completer<int>().future);
    scheduler.elapse(const Duration(seconds: 5));

    expect(await future, isOperationTimedOut);
  });
}
