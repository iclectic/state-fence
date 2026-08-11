import 'package:state_fence/state_fence.dart';
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
  const _Data(this.results);
  final List<String> results;
}

final class _Error extends _SearchState {
  const _Error(this.message);
  final String message;
}

final class _Other extends _SearchState {
  const _Other();
}

class _CollectingReporter implements StateFenceReporter {
  final List<StateFenceViolation> violations = [];

  @override
  void report(StateFenceViolation violation) {
    violations.add(violation);
  }
}

StateFence<_SearchState> _createFence({
  _SearchState? initial,
  List<TransitionRule>? rules,
  StateFenceReporter? reporter,
  bool captureStackTrace = false,
}) {
  return StateFence<_SearchState>(
    name: 'search',
    initialState: initial ?? const _Idle(),
    rules: rules ??
        [
          allow<_Idle, _Loading>(),
          allow<_Loading, _Data>(),
          allow<_Loading, _Error>(),
          allow<_Error, _Loading>(),
        ],
    reporter: reporter,
    captureStackTrace: captureStackTrace,
  );
}

void main() {
  group('StateFence', () {
    test('allows a valid transition and updates current state', () {
      final fence = _createFence();
      final result = fence.transition(const _Loading());

      expect(result, isA<TransitionAccepted<_SearchState>>());
      expect(fence.current, isA<_Loading>());
    });

    test('rejects an invalid transition without changing state', () {
      final fence = _createFence();
      final result = fence.transition(const _Error('failed'));

      expect(result, isA<TransitionRejected<_SearchState>>());
      expect(fence.current, isA<_Idle>());
    });

    test('rejects transition from an intermediate state', () {
      final fence = _createFence()..transition(const _Loading());
      final result = fence.transition(const _Other());

      expect(result, isA<TransitionRejected<_SearchState>>());
      expect(fence.current, isA<_Loading>());
    });

    test('supports transition from an error state back to loading', () {
      final fence = _createFence(
        initial: const _Error('failed'),
      );
      final result = fence.transition(const _Loading());

      expect(result, isA<TransitionAccepted<_SearchState>>());
      expect(fence.current, isA<_Loading>());
    });

    test('reports violations through an injected reporter', () {
      final reporter = _CollectingReporter();
      final fence = _createFence(reporter: reporter);

      fence.transition(const _Other());

      expect(reporter.violations, hasLength(1));
      final violation = reporter.violations.single as TransitionViolation;
      expect(violation.source, 'search');
      expect(violation.previousState, _Idle);
      expect(violation.attemptedState, _Other);
    });

    test('violations include operation and metadata', () {
      final reporter = _CollectingReporter();
      final fence = _createFence(reporter: reporter);

      fence.transition(
        const _Other(),
        operation: 'submit',
        metadata: const {'query': 'books'},
      );

      final violation = reporter.violations.single;
      expect(violation.operation, 'submit');
      expect(violation.safeMetadata, {'query': 'books'});
    });

    test('captures a stack trace only when enabled', () {
      final reporter = _CollectingReporter();
      final off = _createFence(reporter: reporter, captureStackTrace: false);
      final on = _createFence(reporter: reporter, captureStackTrace: true);

      off.transition(const _Other());
      expect(reporter.violations.first.stackTrace, isNull);

      on.transition(const _Other());
      expect(reporter.violations.last.stackTrace, isNotNull);
    });

    test('rejected result contains the violation', () {
      final fence = _createFence();
      final result = fence.transition(const _Other());

      expect(result, isA<TransitionRejected<_SearchState>>());
      final rejected = result as TransitionRejected<_SearchState>;
      final violation = rejected.violation as TransitionViolation;
      expect(violation.reason, contains('not allowed'));
      expect(violation.previousState, _Idle);
      expect(violation.attemptedState, _Other);
    });

    test('timestamp is within the test run', () {
      final before = DateTime.now();
      final fence = _createFence();
      final result = fence.transition(const _Other());
      final after = DateTime.now();

      final rejected = result as TransitionRejected<_SearchState>;
      expect(
        rejected.violation.timestamp
                .isAfter(before.subtract(const Duration(seconds: 1))) &&
            rejected.violation.timestamp
                .isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
    });

    test('metadata map is unmodifiable', () {
      final reporter = _CollectingReporter();
      final fence = _createFence(reporter: reporter);

      fence.transition(
        const _Other(),
        metadata: {'query': 'books'},
      );

      final metadata = reporter.violations.single.safeMetadata;
      expect(() => metadata['query'] = 'changed', throwsUnsupportedError);
    });
  });

  group('StateFence.dispose', () {
    test('transition after dispose reports UseAfterDisposeViolation', () {
      final reporter = _CollectingReporter();
      final fence = _createFence(reporter: reporter)..dispose();

      final result = fence.transition(const _Loading());

      expect(result, isA<TransitionRejected<_SearchState>>());
      expect(reporter.violations.single, isA<UseAfterDisposeViolation>());
      expect(fence.isDisposed, isTrue);
    });

    test('dispose is idempotent and records one OwnerDisposedEvent', () {
      final timeline = Timeline(capacity: 10);
      final fence = StateFence<_SearchState>(
        name: 'search',
        initialState: const _Idle(),
        rules: [allow<_Idle, _Loading>()],
        timeline: timeline,
      );

      fence.dispose();
      fence.dispose();

      expect(timeline.eventsOfType<OwnerDisposedEvent>(), hasLength(1));
    });
  });

  group('StateFence stuck-state detection', () {
    test('reports a StuckStateViolation when a state exceeds its maximum', () {
      final reporter = _CollectingReporter();
      final scheduler = FakeFenceScheduler();
      final timeline = Timeline(capacity: 10);

      final fence = StateFence<_SearchState>(
        name: 'search',
        initialState: const _Idle(),
        rules: [allow<_Idle, _Loading>(), allow<_Loading, _Data>()],
        reporter: reporter,
        scheduler: scheduler,
        timeline: timeline,
        stuckStateTimeouts: const {_Loading: Duration(seconds: 10)},
      );

      fence.transition(const _Loading());
      scheduler.elapse(const Duration(seconds: 10));

      final violation = reporter.violations.single as StuckStateViolation;
      expect(violation.stuckState, _Loading);
      expect(violation.maxDuration, const Duration(seconds: 10));
      expect(timeline.eventsOfType<StateStuckEvent>(), hasLength(1));
    });

    test('does not report when the state is left before the maximum', () {
      final reporter = _CollectingReporter();
      final scheduler = FakeFenceScheduler();

      final fence = StateFence<_SearchState>(
        name: 'search',
        initialState: const _Idle(),
        rules: [allow<_Idle, _Loading>(), allow<_Loading, _Data>()],
        reporter: reporter,
        scheduler: scheduler,
        stuckStateTimeouts: const {_Loading: Duration(seconds: 10)},
      );

      fence.transition(const _Loading());
      scheduler.elapse(const Duration(seconds: 5));
      fence.transition(const _Data([]));
      scheduler.elapse(const Duration(seconds: 10));

      expect(reporter.violations, isEmpty);
    });

    test('monitors the initial state when it has a declared timeout', () {
      final reporter = _CollectingReporter();
      final scheduler = FakeFenceScheduler();

      StateFence<_SearchState>(
        name: 'search',
        initialState: const _Loading(),
        rules: [allow<_Loading, _Data>()],
        reporter: reporter,
        scheduler: scheduler,
        stuckStateTimeouts: const {_Loading: Duration(seconds: 3)},
      );

      scheduler.elapse(const Duration(seconds: 3));

      expect(reporter.violations.single, isA<StuckStateViolation>());
    });

    test('does not report after the fence is disposed', () {
      final reporter = _CollectingReporter();
      final scheduler = FakeFenceScheduler();

      final fence = StateFence<_SearchState>(
        name: 'search',
        initialState: const _Loading(),
        rules: [allow<_Loading, _Data>()],
        reporter: reporter,
        scheduler: scheduler,
        stuckStateTimeouts: const {_Loading: Duration(seconds: 3)},
      );

      fence.dispose();
      scheduler.elapse(const Duration(seconds: 3));

      expect(reporter.violations, isEmpty);
    });
  });
}
