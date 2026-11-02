import 'dart:async';

import 'package:state_fence/state_fence.dart';
import 'package:test/test.dart';

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  group('OperationPolicy.restartable', () {
    test('completes the previous run as stale when a new one starts', () async {
      final older = Completer<int>();
      final op = GuardedOperation<int>(
        name: 'search',
        policy: OperationPolicy.restartable,
      );

      final olderFuture = op.run(() => older.future);
      final newerFuture = op.run(() async => 2);

      expect(await olderFuture, isA<OperationIgnoredAsStale<int>>());
      expect(await newerFuture, isA<OperationSuccess<int>>());
      older.complete(1);
    });
  });

  group('OperationPolicy.sequential', () {
    test('runs the second action only after the first settles', () async {
      final gate = Completer<int>();
      var secondStarted = false;
      final op = GuardedOperation<int>(
        name: 'save',
        policy: OperationPolicy.sequential,
      );

      final first = op.run(() => gate.future);
      final second = op.run(() async {
        secondStarted = true;
        return 2;
      });
      await _flush();
      expect(secondStarted, isFalse);

      gate.complete(1);
      expect(await first, isA<OperationSuccess<int>>());
      expect(await second, isA<OperationSuccess<int>>());
      expect(secondStarted, isTrue);
    });
  });

  group('OperationPolicy.firstWins', () {
    test('does not record a start event for a duplicate', () async {
      final timeline = Timeline();
      final gate = Completer<int>();
      final op = GuardedOperation<int>(
        name: 'pay',
        policy: OperationPolicy.firstWins,
        timeline: timeline,
      );

      final first = op.run(() => gate.future);
      final duplicate = await op.run(() async => 2);
      expect(duplicate, isA<OperationIgnoredAsDuplicate<int>>());
      expect(timeline.eventsOfType<OperationStartedEvent>(), hasLength(1));
      gate.complete(1);
      await first;
    });
  });

  group('OperationPolicy.parallel', () {
    test('accepts overlapping invocations', () async {
      final firstGate = Completer<int>();
      final secondGate = Completer<int>();
      final op = GuardedOperation<int>(
        name: 'load',
        policy: OperationPolicy.parallel,
      );

      final first = op.run(() => firstGate.future);
      final second = op.run(() => secondGate.future);
      secondGate.complete(2);
      firstGate.complete(1);

      expect(await first, isA<OperationSuccess<int>>());
      expect((await first).token, isNot((await second).token));
      final secondOutcome = await second;
      expect(secondOutcome, isA<OperationSuccess<int>>());
      expect((secondOutcome as OperationSuccess<int>).value, 2);
    });
  });

  group('OperationPolicy.sequential', () {
    test('starts the queued action after a timeout', () async {
      final scheduler = FakeFenceScheduler();
      final op = GuardedOperation<int>(
        name: 'save',
        policy: OperationPolicy.sequential,
        timeout: const Duration(seconds: 5),
        scheduler: scheduler,
      );
      final first = op.run(() => Completer<int>().future);
      var secondStarted = false;
      final second = op.run(() async {
        secondStarted = true;
        return 2;
      });

      scheduler.elapse(const Duration(seconds: 5));
      await _flush();

      expect(await first, isA<OperationTimedOut<int>>());
      expect(secondStarted, isTrue);
      expect(await second, isA<OperationSuccess<int>>());
    });
  });

  group('RetryPolicy', () {
    test('retries a failure on the fake scheduler and then accepts', () async {
      final scheduler = FakeFenceScheduler();
      var calls = 0;
      final op = GuardedOperation<int>(
        name: 'load',
        policy: OperationPolicy.latestWins,
        scheduler: scheduler,
        retry: const RetryPolicy(
          maxAttempts: 3,
          initialDelay: Duration(seconds: 1),
          multiplier: 2,
        ),
      );

      final future = op.run(() async {
        calls++;
        if (calls < 3) throw StateError('not yet');
        return 7;
      });

      await _flush();
      expect(calls, 1);
      scheduler.elapse(const Duration(seconds: 1));
      await _flush();
      expect(calls, 2);
      scheduler.elapse(const Duration(seconds: 2));
      await _flush();

      final outcome = await future;
      expect(outcome, isA<OperationSuccess<int>>());
      expect((outcome as OperationSuccess<int>).value, 7);
      expect(calls, 3);
    });

    test('caps the backoff at maxDelay', () {
      const policy = RetryPolicy(
        initialDelay: Duration(seconds: 10),
        multiplier: 4,
        maxDelay: Duration(seconds: 30),
      );

      expect(policy.delayAfter(1), const Duration(seconds: 10));
      expect(policy.delayAfter(2), const Duration(seconds: 30));
    });

    test('does not retry a timeout', () async {
      final scheduler = FakeFenceScheduler();
      var calls = 0;
      final op = GuardedOperation<int>(
        name: 'load',
        policy: OperationPolicy.latestWins,
        timeout: const Duration(seconds: 5),
        scheduler: scheduler,
        retry: const RetryPolicy(maxAttempts: 3),
      );

      final future = op.run(() {
        calls++;
        return Completer<int>().future;
      });
      scheduler.elapse(const Duration(seconds: 5));

      expect(await future, isA<OperationTimedOut<int>>());
      expect(calls, 1);
    });
  });
}
