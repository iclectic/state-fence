import 'dart:convert';

import 'package:state_fence/state_fence.dart';
import 'package:test/test.dart';

void main() {
  const secret = 'super-secret-token';

  group('error descriptions', () {
    test('default export records the runtime type and omits the message',
        () async {
      final timeline = Timeline(capacity: 8);
      final operation = GuardedOperation<int>(
        name: 'pay',
        policy: OperationPolicy.parallel,
        timeline: timeline,
      );

      final outcome = await operation.run(() async => throw StateError(secret));

      expect(outcome, isA<OperationFailure<int>>());
      final failure = outcome as OperationFailure<int>;
      expect(failure.error.toString(), contains(secret));

      final recorded = timeline.events.whereType<OperationFailedEvent>().single;
      expect(recorded.errorDescription, 'StateError');
      expect(recorded.errorDescription, isNot(contains(secret)));

      final json = exportTimelineJson(timeline);
      expect(json, contains('StateError'));
      expect(json, isNot(contains(secret)));
      final event = _failedEvent(json);
      expect(event['errorDescription'], 'StateError');
    });

    test('describeErrorMessage opts the full message into the export',
        () async {
      final timeline = Timeline(capacity: 8);
      final operation = GuardedOperation<int>(
        name: 'pay',
        policy: OperationPolicy.parallel,
        timeline: timeline,
        errorDescriber: describeErrorMessage,
      );

      await operation.run(() async => throw StateError(secret));

      final recorded = timeline.events.whereType<OperationFailedEvent>().single;
      expect(recorded.errorDescription, contains(secret));
      final json = exportTimelineJson(timeline);
      expect(json, contains(secret));
      expect(_failedEvent(json)['errorDescription'], contains(secret));
    });

    test('a custom describer is what the export writes', () async {
      final timeline = Timeline(capacity: 8);
      final operation = GuardedOperation<int>(
        name: 'pay',
        policy: OperationPolicy.parallel,
        timeline: timeline,
        errorDescriber: (Object error, StackTrace stackTrace) => 'failed',
      );

      await operation.run(() async => throw StateError(secret));

      final json = exportTimelineJson(timeline);
      expect(_failedEvent(json)['errorDescription'], 'failed');
      expect(json, isNot(contains(secret)));
    });

    test('a retried failure uses the same describer', () async {
      final scheduler = FakeFenceScheduler();
      final timeline = Timeline(capacity: 8);
      var calls = 0;
      final operation = GuardedOperation<int>(
        name: 'pay',
        policy: OperationPolicy.parallel,
        timeline: timeline,
        scheduler: scheduler,
        retry: const RetryPolicy(
          maxAttempts: 2,
          initialDelay: Duration(milliseconds: 5),
        ),
      );

      final future = operation.run(() async {
        calls++;
        if (calls == 1) throw FormatException(secret);
        return 1;
      });

      await Future<void>.delayed(Duration.zero);
      final recorded = timeline.events.whereType<OperationFailedEvent>().single;
      expect(recorded.errorDescription, 'FormatException');
      expect(exportTimelineJson(timeline), isNot(contains(secret)));

      scheduler.elapse(const Duration(milliseconds: 5));
      await Future<void>.delayed(Duration.zero);
      expect(await future, isA<OperationSuccess<int>>());
    });
  });
}

Map<Object?, Object?> _failedEvent(String json) {
  final envelope = jsonDecode(json) as Map<Object?, Object?>;
  final events = envelope['events'] as List<Object?>;
  return events.cast<Map<Object?, Object?>>().singleWhere(
        (Map<Object?, Object?> event) => event['kind'] == 'operationFailed',
      );
}
