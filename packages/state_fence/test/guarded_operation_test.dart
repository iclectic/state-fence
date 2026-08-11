import 'dart:async';

import 'package:state_fence/state_fence.dart';
import 'package:test/test.dart';

class _CollectingReporter implements StateFenceReporter {
  final List<StateFenceViolation> violations = [];

  @override
  void report(StateFenceViolation violation) {
    violations.add(violation);
  }
}

void main() {
  group('GuardedOperation.latestWins', () {
    test('accepts a single successful result', () async {
      final op = GuardedOperation<int>(
        name: 'search',
        policy: OperationPolicy.latestWins,
      );

      final outcome = await op.run(() async => 42);

      expect(outcome, isA<OperationSuccess<int>>());
      expect((outcome as OperationSuccess<int>).value, 42);
    });

    test('accepts the newest result and ignores older results as stale',
        () async {
      // Two requests completing in reverse order: the older one resolves last.
      final olderCompleter = Completer<int>();
      final newerCompleter = Completer<int>();

      final op = GuardedOperation<int>(
        name: 'search',
        policy: OperationPolicy.latestWins,
      );

      final olderFuture = op.run(() => olderCompleter.future);
      final newerFuture = op.run(() => newerCompleter.future);

      // Newer resolves first and is accepted.
      newerCompleter.complete(2);
      final newerOutcome = await newerFuture;
      expect(newerOutcome, isA<OperationSuccess<int>>());
      expect((newerOutcome as OperationSuccess<int>).value, 2);

      // Older resolves afterwards and is ignored as stale.
      olderCompleter.complete(1);
      final olderOutcome = await olderFuture;
      expect(olderOutcome, isA<OperationIgnoredAsStale<int>>());
      final stale = olderOutcome as OperationIgnoredAsStale<int>;
      expect(stale.supersededBy.value, greaterThan(stale.token.value));
    });

    test('accepts the newest of three overlapping invocations', () async {
      final Completer<int> c1 = Completer<int>();
      final Completer<int> c2 = Completer<int>();
      final Completer<int> c3 = Completer<int>();

      final op = GuardedOperation<int>(
        name: 'search',
        policy: OperationPolicy.latestWins,
      );

      final f1 = op.run(() => c1.future);
      final f2 = op.run(() => c2.future);
      final f3 = op.run(() => c3.future);

      // Resolve in reverse order: 3, 2, 1.
      c3.complete(30);
      c2.complete(20);
      c1.complete(10);

      final o3 = await f3;
      final o2 = await f2;
      final o1 = await f1;

      expect(o3, isA<OperationSuccess<int>>());
      expect((o3 as OperationSuccess<int>).value, 30);

      expect(o2, isA<OperationIgnoredAsStale<int>>());
      expect(o1, isA<OperationIgnoredAsStale<int>>());
    });

    test('reports failure for the newest invocation', () async {
      final op = GuardedOperation<int>(
        name: 'search',
        policy: OperationPolicy.latestWins,
      );

      final outcome = await op.run(() async => throw StateError('boom'));

      expect(outcome, isA<OperationFailure<int>>());
      final failure = outcome as OperationFailure<int>;
      expect(failure.error, isA<StateError>());
    });

    test('ignores an older failure as stale when a newer call is accepted',
        () async {
      final Completer<int> older = Completer<int>();
      final Completer<int> newer = Completer<int>();

      final op = GuardedOperation<int>(
        name: 'search',
        policy: OperationPolicy.latestWins,
      );

      final olderFuture = op.run(() => older.future);
      final newerFuture = op.run(() => newer.future);

      newerCompleter(newer, 7);
      await newerFuture;

      olderCompleterError(older, StateError('too late'));
      final olderOutcome = await olderFuture;

      expect(olderOutcome, isA<OperationIgnoredAsStale<int>>());
    });

    test('resolves with OperationTimedOut when the timeout fires', () async {
      final reporter = _CollectingReporter();
      final scheduler = FakeFenceScheduler();
      final completer = Completer<int>();

      final op = GuardedOperation<int>(
        name: 'search',
        policy: OperationPolicy.latestWins,
        timeout: const Duration(seconds: 5),
        reporter: reporter,
        scheduler: scheduler,
      );

      final future = op.run(() => completer.future);

      scheduler.elapse(const Duration(seconds: 5));
      expect(reporter.violations, hasLength(1));
      final violation = reporter.violations.single as OperationTimeoutViolation;
      expect(violation.reason, contains('timed out'));
      expect(violation.timeout, const Duration(seconds: 5));

      // The run future resolves immediately with a timed-out outcome, even
      // though the underlying action never completes.
      final outcome = await future;
      expect(outcome, isA<OperationTimedOut<int>>());
      expect(
        (outcome as OperationTimedOut<int>).timeout,
        const Duration(seconds: 5),
      );
    });

    test('discards a late result that arrives after the timeout', () async {
      final scheduler = FakeFenceScheduler();
      final completer = Completer<int>();

      final op = GuardedOperation<int>(
        name: 'search',
        policy: OperationPolicy.latestWins,
        timeout: const Duration(seconds: 5),
        scheduler: scheduler,
      );

      final future = op.run(() => completer.future);
      scheduler.elapse(const Duration(seconds: 5));

      final outcome = await future;
      expect(outcome, isA<OperationTimedOut<int>>());

      // The late completion is discarded silently; the outcome is unchanged.
      completer.complete(99);
      await Future<void>.delayed(Duration.zero);
      expect(await future, same(outcome));
    });

    test('does not time out when the result arrives first', () async {
      final reporter = _CollectingReporter();
      final scheduler = FakeFenceScheduler();

      final op = GuardedOperation<int>(
        name: 'search',
        policy: OperationPolicy.latestWins,
        timeout: const Duration(seconds: 5),
        reporter: reporter,
        scheduler: scheduler,
      );

      final outcome = await op.run(() async => 1);

      scheduler.elapse(const Duration(seconds: 10));
      expect(reporter.violations, isEmpty);
      expect(outcome, isA<OperationSuccess<int>>());
    });
  });

  group('GuardedOperation.firstWins', () {
    test('accepts the first invocation and ignores duplicates', () async {
      final Completer<int> first = Completer<int>();

      final op = GuardedOperation<int>(
        name: 'submit',
        policy: OperationPolicy.firstWins,
      );

      final firstFuture = op.run(() => first.future);
      final duplicateFuture = op.run(() async => 999);

      final duplicateOutcome = await duplicateFuture;
      expect(duplicateOutcome, isA<OperationIgnoredAsDuplicate<int>>());
      final duplicate = duplicateOutcome as OperationIgnoredAsDuplicate<int>;
      expect(duplicate.blockedBy, isNot(duplicate.token));

      first.complete(1);
      final firstOutcome = await firstFuture;
      expect(firstOutcome, isA<OperationSuccess<int>>());
      expect((firstOutcome as OperationSuccess<int>).value, 1);
    });

    test('allows a new invocation after the first completes', () async {
      final op = GuardedOperation<int>(
        name: 'submit',
        policy: OperationPolicy.firstWins,
      );

      final first = await op.run(() async => 1);
      expect(first, isA<OperationSuccess<int>>());

      final second = await op.run(() async => 2);
      expect(second, isA<OperationSuccess<int>>());
      expect((second as OperationSuccess<int>).value, 2);
    });

    test('allows a new invocation after the first fails', () async {
      final op = GuardedOperation<int>(
        name: 'submit',
        policy: OperationPolicy.firstWins,
      );

      final first = await op.run(() async => throw StateError('no'));
      expect(first, isA<OperationFailure<int>>());

      final second = await op.run(() async => 2);
      expect(second, isA<OperationSuccess<int>>());
    });

    test('allows a retry after a timed-out invocation', () async {
      final scheduler = FakeFenceScheduler();
      final stuck = Completer<int>();

      final op = GuardedOperation<int>(
        name: 'submit',
        policy: OperationPolicy.firstWins,
        timeout: const Duration(seconds: 5),
        scheduler: scheduler,
      );

      final future = op.run(() => stuck.future);
      scheduler.elapse(const Duration(seconds: 5));

      final timedOut = await future;
      expect(timedOut, isA<OperationTimedOut<int>>());

      // The timed-out invocation no longer blocks a retry.
      final retry = await op.run(() async => 2);
      expect(retry, isA<OperationSuccess<int>>());
    });
  });

  group('GuardedOperation.dispose', () {
    test('run after dispose reports a violation and returns failure', () async {
      final reporter = _CollectingReporter();
      final op = GuardedOperation<int>(
        name: 'search',
        policy: OperationPolicy.latestWins,
        reporter: reporter,
      );

      op.dispose();

      final outcome = await op.run(() async => 1);

      expect(outcome, isA<OperationFailure<int>>());
      expect(reporter.violations, hasLength(1));
      expect(reporter.violations.single.reason, contains('dispose'));
    });

    test('in-flight result after dispose returns failure', () async {
      final reporter = _CollectingReporter();
      final Completer<int> completer = Completer<int>();

      final op = GuardedOperation<int>(
        name: 'search',
        policy: OperationPolicy.latestWins,
        reporter: reporter,
      );

      final future = op.run(() => completer.future);
      op.dispose();

      completer.complete(1);
      final outcome = await future;

      expect(outcome, isA<OperationFailure<int>>());
      expect(
          reporter.violations.any((v) => v.reason.contains('dispose')), isTrue);
    });
  });
}

void newerCompleter(Completer<int> c, int value) => c.complete(value);
void olderCompleterError(Completer<int> c, Object error) =>
    c.completeError(error);
