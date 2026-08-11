import 'package:state_fence/state_fence.dart';
import 'package:state_fence_test/state_fence_test.dart';
import 'package:test/test.dart';

sealed class _SearchState {
  const _SearchState();
}

final class _Idle extends _SearchState {
  const _Idle();
}

final class _Loading extends _SearchState {
  const _Loading();
}

final class _Data extends _SearchState {
  const _Data();
}

StateFence<_SearchState> _createFence({StateFenceReporter? reporter}) {
  return StateFence<_SearchState>(
    name: 'search',
    initialState: const _Idle(),
    rules: [
      allow<_Idle, _Loading>(),
      allow<_Loading, _Data>(),
    ],
    reporter: reporter,
  );
}

void main() {
  group('transition matchers', () {
    test('allowsTransition matches a declared rule', () {
      expect(_createFence(), allowsTransition<_Idle, _Loading>());
    });

    test('rejectsTransition matches an undeclared rule', () {
      expect(_createFence(), rejectsTransition<_Idle, _Data>());
    });
  });

  group('outcome matchers', () {
    test('isOperationSuccess matches success and optional value', () async {
      final op = GuardedOperation<int>(
        name: 'op',
        policy: OperationPolicy.latestWins,
      );

      final outcome = await op.run(() async => 42);

      expect(outcome, isOperationSuccess());
      expect(outcome, isOperationSuccess(value: 42));
      expect(outcome, isNot(isOperationSuccess(value: 7)));
    });

    test('isOperationFailure matches failures', () async {
      final op = GuardedOperation<int>(
        name: 'op',
        policy: OperationPolicy.latestWins,
      );

      final outcome = await op.run(() async => throw StateError('boom'));

      expect(outcome, isOperationFailure);
      expect(outcome, isNot(isOperationSuccess()));
    });

    test('isOperationTimedOut matches timeouts', () async {
      final scheduler = FakeFenceScheduler();
      final op = GuardedOperation<int>(
        name: 'op',
        policy: OperationPolicy.latestWins,
        timeout: const Duration(seconds: 1),
        scheduler: scheduler,
      );

      final future = op.run(() => Future.any([]));
      scheduler.elapse(const Duration(seconds: 1));

      expect(await future, isOperationTimedOut);
    });
  });

  group('CollectingReporter', () {
    test('collects violations and filters by type', () {
      final reporter = CollectingReporter();
      final fence = _createFence(reporter: reporter);

      fence.transition(const _Data());

      expect(reporter.hasViolations, isTrue);
      expect(reporter.violationsOfType<TransitionViolation>(), hasLength(1));
      expect(reporter.violationsOfType<StuckStateViolation>(), isEmpty);

      reporter.clear();
      expect(reporter.violations, hasNoViolations);
    });
  });

  group('ThrowingReporter', () {
    test('throws on the first violation', () {
      final fence = _createFence(reporter: const ThrowingReporter());

      expect(() => fence.transition(const _Data()), throwsStateError);
    });
  });
}
