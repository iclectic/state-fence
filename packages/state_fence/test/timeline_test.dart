import 'dart:async';
import 'dart:convert';

import 'package:state_fence/state_fence.dart';
import 'package:test/test.dart';

void main() {
  group('Timeline', () {
    test('retains events up to capacity', () {
      final timeline = Timeline(capacity: 3);
      for (var i = 0; i < 3; i++) {
        timeline.add(
          TransitionAcceptedEvent(
            source: 'fence',
            timestamp: DateTime(2026, 1, 1, 0, 0, i),
            fromState: int,
            toState: String,
          ),
        );
      }

      expect(timeline.length, 3);
      expect(timeline.droppedCount, 0);
    });

    test('drops oldest events when capacity is exceeded', () {
      final timeline = Timeline(capacity: 2);

      final first = TransitionAcceptedEvent(
        source: 'fence',
        timestamp: DateTime(2026, 1, 1),
        fromState: int,
        toState: String,
      );
      final second = TransitionAcceptedEvent(
        source: 'fence',
        timestamp: DateTime(2026, 1, 2),
        fromState: int,
        toState: String,
      );
      final third = TransitionAcceptedEvent(
        source: 'fence',
        timestamp: DateTime(2026, 1, 3),
        fromState: int,
        toState: String,
      );

      timeline.add(first);
      timeline.add(second);
      timeline.add(third);

      expect(timeline.length, 2);
      expect(timeline.droppedCount, 1);
      expect(timeline.events.first, second);
      expect(timeline.events.last, third);
    });

    test('clear removes all events and resets dropped count', () {
      final timeline = Timeline(capacity: 5);
      timeline.add(
        TransitionAcceptedEvent(
          source: 'fence',
          timestamp: DateTime(2026, 1, 1),
          fromState: int,
          toState: String,
        ),
      );

      timeline.clear();

      expect(timeline.isEmpty, isTrue);
      expect(timeline.droppedCount, 0);
    });
  });

  group('MetadataRedactor', () {
    test('redacts default sensitive keys', () {
      const redactor = MetadataRedactor();

      final result = redactor.redact({
        'password': 'hunter2',
        'token': 'abc',
        'username': 'alice',
      });

      expect(result, {
        'password': '<redacted>',
        'token': '<redacted>',
        'username': 'alice',
      });
    });

    test('redacts nested maps', () {
      const redactor = MetadataRedactor();

      final result = redactor.redact({
        'user': {
          'name': 'alice',
          'secret': 'topsecret',
        },
      });

      expect(result, {
        'user': {
          'name': 'alice',
          'secret': '<redacted>',
        },
      });
    });

    test('redacts nested lists containing maps', () {
      const redactor = MetadataRedactor();

      final result = redactor.redact({
        'headers': [
          {'cookie': 'session=abc'},
          {'content-type': 'application/json'},
        ],
      });

      expect(result, {
        'headers': [
          {'cookie': '<redacted>'},
          {'content-type': 'application/json'},
        ],
      });
    });

    test('matches keys case-insensitively', () {
      const redactor = MetadataRedactor();

      final result = redactor.redact({
        'Password': 'x',
        'TOKEN': 'y',
      });

      expect(result, {
        'Password': '<redacted>',
        'TOKEN': '<redacted>',
      });
    });

    test('uses a custom redactor callback when provided', () {
      const redactor = MetadataRedactor(
        redactor: _customRedactor,
      );

      final result = redactor.redact({
        'iban': 'GB00WESTERN123',
        'password': 'hunter2',
      });

      expect(result, {
        'iban': '<custom-redacted>',
        'password': '<redacted>',
      });
    });

    test('returns scalars unchanged at the top level', () {
      const redactor = MetadataRedactor();

      expect(redactor.redact('hello'), 'hello');
      expect(redactor.redact(42), 42);
      expect(redactor.redact(null), null);
    });

    test('redacts an entire map subtree under a sensitive key', () {
      const redactor = MetadataRedactor();

      final result = redactor.redact({
        'token': {'inner': 'must not leak'},
        'safe': {'inner': 'fine'},
      });

      expect(result, {
        'token': '<redacted>',
        'safe': {'inner': 'fine'},
      });
    });

    test('redacts an entire list subtree under a sensitive key', () {
      const redactor = MetadataRedactor();

      final result = redactor.redact({
        'secret': ['a', 'b'],
        'items': ['x', 'y'],
      });

      expect(result, {
        'secret': '<redacted>',
        'items': ['x', 'y'],
      });
    });
  });

  group('exportTimelineJson', () {
    test('serialises events with kind, source and timestamp', () {
      final timeline = Timeline(capacity: 10);
      timeline.add(
        TransitionAcceptedEvent(
          source: 'search',
          timestamp: DateTime(2026, 1, 1, 12, 0, 0),
          operation: 'query',
          metadata: {'query': 'books'},
          fromState: int,
          toState: String,
        ),
      );

      final json = exportTimelineJson(timeline);
      final envelope = jsonDecode(json) as Map;
      final decoded = envelope['events'] as List;

      expect(envelope['droppedCount'], 0);
      expect(decoded, hasLength(1));
      final event = decoded.single as Map;
      expect(event['kind'], 'transitionAccepted');
      expect(event['source'], 'search');
      expect(event['operation'], 'query');
      expect(event['fromState'], 'int');
      expect(event['toState'], 'String');
      expect(event['metadata'], {'query': 'books'});
    });

    test('redacts sensitive metadata in exported events', () {
      final timeline = Timeline(capacity: 10);
      timeline.add(
        TransitionRejectedEvent(
          source: 'checkout',
          timestamp: DateTime(2026, 1, 1),
          violation: TransitionViolation(
            source: 'checkout',
            previousState: int,
            attemptedState: String,
            timestamp: DateTime(2026, 1, 1),
            reason: 'illegal',
            safeMetadata: const {'token': 'abc', 'amount': 100},
          ),
        ),
      );

      final json = exportTimelineJson(timeline);
      final envelope = jsonDecode(json) as Map;
      final event = (envelope['events'] as List).single as Map;
      final violation = event['violation'] as Map;

      expect(violation['type'], 'transition');
      expect(violation['safeMetadata'], {
        'token': '<redacted>',
        'amount': 100,
      });
    });

    test('serialises operation lifecycle events', () {
      final timeline = Timeline(capacity: 10);
      final token = const OperationToken(5);

      timeline.add(
        OperationStartedEvent(
          source: 'search',
          timestamp: DateTime(2026, 1, 1, 0, 0, 0),
          token: token,
        ),
      );
      timeline.add(
        OperationIgnoredAsStaleEvent(
          source: 'search',
          timestamp: DateTime(2026, 1, 1, 0, 0, 1),
          token: token,
          supersededBy: const OperationToken(6),
        ),
      );
      timeline.add(
        OperationTimedOutEvent(
          source: 'search',
          timestamp: DateTime(2026, 1, 1, 0, 0, 2),
          token: token,
        ),
      );

      final json = exportTimelineJson(timeline);
      final envelope = jsonDecode(json) as Map;
      final decoded = envelope['events'] as List;

      expect(decoded, hasLength(3));
      expect((decoded[0] as Map)['kind'], 'operationStarted');
      expect((decoded[0] as Map)['token'], 5);
      expect((decoded[1] as Map)['kind'], 'operationIgnoredAsStale');
      expect((decoded[1] as Map)['supersededBy'], 6);
      expect((decoded[2] as Map)['kind'], 'operationTimedOut');
    });

    test('exports droppedCount when the ring buffer overflows', () {
      final timeline = Timeline(capacity: 1);
      for (var i = 0; i < 3; i++) {
        timeline.add(
          OperationStartedEvent(
            source: 'search',
            timestamp: DateTime(2026, 1, 1, 0, 0, i),
            token: OperationToken(i),
          ),
        );
      }

      final envelope = jsonDecode(exportTimelineJson(timeline)) as Map;
      expect(envelope['droppedCount'], 2);
      expect(envelope['events'], hasLength(1));
    });
  });

  group('throwing reporters', () {
    test('timeline records the event before the reporter throws', () {
      final timeline = Timeline(capacity: 10);
      final fence = StateFence<int>(
        name: 'fence',
        initialState: 0,
        rules: [allow<int, String>()],
        reporter: _ThrowingReporter(),
        timeline: timeline,
      );

      // This transition is invalid (int -> int). The throwing reporter
      // enables strict mode, so the call throws, but the timeline event is
      // recorded first.
      expect(() => fence.transition(1), throwsStateError);

      expect(timeline.length, 1);
      expect(timeline.events.single, isA<TransitionRejectedEvent>());
    });

    test('a throwing reporter cannot hang an operation timeout', () async {
      final scheduler = FakeFenceScheduler();
      final op = GuardedOperation<int>(
        name: 'op',
        policy: OperationPolicy.latestWins,
        timeout: const Duration(seconds: 1),
        reporter: _ThrowingReporter(),
        scheduler: scheduler,
      );

      final future = op.run(() => Completer<int>().future);
      scheduler.elapse(const Duration(seconds: 1));

      // The outcome resolves even though the reporter throws in the timer.
      expect(await future, isA<OperationTimedOut<int>>());
    });
  });
}

Object? _customRedactor(String key, Object? value) {
  if (key == 'iban') return '<custom-redacted>';
  return null;
}

final class _ThrowingReporter implements StateFenceReporter {
  @override
  void report(StateFenceViolation violation) {
    throw StateError('reporter failed');
  }
}
