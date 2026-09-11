import 'dart:convert';

import 'package:state_fence/state_fence.dart';
import 'package:test/test.dart';

class _Opaque {
  const _Opaque();

  @override
  String toString() => 'Opaque()';
}

class _Loading {
  const _Loading();
}

void main() {
  group('MetadataRedactor robustness', () {
    test('redacts nested maps whose keys are not Strings', () {
      const redactor = MetadataRedactor();

      final result = redactor.redact({
        'outer': {1: 'one', 2: 'two'},
      });

      expect(result, {
        'outer': {'1': 'one', '2': 'two'},
      });
    });

    test('matches a stringified non-String key against sensitive keys', () {
      const redactor = MetadataRedactor(sensitiveKeys: {'42'});

      expect(redactor.redact({42: 'secret'}), {'42': '<redacted>'});
    });

    test('stringifies a null map key rather than throwing', () {
      const redactor = MetadataRedactor();

      expect(redactor.redact({null: 'value'}), {'null': 'value'});
    });

    test('converts non-List iterables into lists', () {
      const redactor = MetadataRedactor();

      expect(
          redactor.redact({
            'ids': {1, 2, 3}
          }),
          {
            'ids': [1, 2, 3],
          });
    });

    test('truncates instead of recursing forever on a self-reference', () {
      const redactor = MetadataRedactor(maxDepth: 4);
      final cyclic = <String, Object?>{'name': 'root'};
      cyclic['self'] = cyclic;

      final result = redactor.redact(cyclic) as Map<String, Object?>;

      expect(result['name'], 'root');
      expect(
        const JsonEncoder().convert(result),
        contains('<truncated>'),
      );
    });

    test('truncates nesting deeper than maxDepth', () {
      const redactor = MetadataRedactor(maxDepth: 2);

      final result = redactor.redact({
        'a': {
          'b': {'c': 'deep'},
        },
      });

      expect(result, {
        'a': {'b': '<truncated>'},
      });
    });
  });

  group('exportTimelineJson robustness', () {
    test('encodes metadata values that JSON cannot represent natively', () {
      final timeline = Timeline();
      timeline.add(
        StateStuckEvent(
          source: 'fence',
          timestamp: DateTime.utc(2026, 1, 1),
          metadata: {
            'at': DateTime.utc(2026, 1, 2),
            'took': const Duration(seconds: 3),
            'opaque': const _Opaque(),
          },
          stuckState: _Loading,
          maxDuration: const Duration(seconds: 1),
        ),
      );

      final decoded =
          jsonDecode(exportTimelineJson(timeline)) as Map<String, Object?>;
      final events = decoded['events'] as List<Object?>;
      final metadata =
          (events.single as Map<String, Object?>)['metadata']! as Map;

      expect(metadata['at'], '2026-01-02 00:00:00.000Z');
      expect(metadata['took'], '0:00:03.000000');
      expect(metadata['opaque'], 'Opaque()');
    });

    test('exports a timeline holding a cyclic metadata map', () {
      final timeline = Timeline();
      final cyclic = <String, Object?>{'kind': 'cyclic'};
      cyclic['self'] = cyclic;
      timeline.add(
        OwnerDisposedEvent(
          source: 'fence',
          timestamp: DateTime.utc(2026, 1, 1),
          metadata: cyclic,
        ),
      );

      expect(() => exportTimelineJson(timeline), returnsNormally);
    });
  });

  group('FakeFenceScheduler', () {
    test('fires a timer scheduled inside a callback in chronological order',
        () {
      final scheduler = FakeFenceScheduler();
      final fired = <String>[];

      scheduler.timer(const Duration(seconds: 5), () {
        fired.add('outer');
        scheduler.timer(const Duration(seconds: 1), () => fired.add('inner'));
      });
      scheduler.timer(const Duration(seconds: 10), () => fired.add('late'));

      scheduler.elapse(const Duration(seconds: 20));

      expect(fired, ['outer', 'inner', 'late']);
    });

    test('never moves the clock backwards for a zero-duration timer', () {
      final scheduler = FakeFenceScheduler(initialTime: DateTime.utc(2026));
      final seen = <DateTime>[];

      scheduler.timer(const Duration(seconds: 5), () {
        seen.add(scheduler.now());
        scheduler.timer(Duration.zero, () => seen.add(scheduler.now()));
      });

      scheduler.elapse(const Duration(seconds: 10));

      expect(seen, [
        DateTime.utc(2026).add(const Duration(seconds: 5)),
        DateTime.utc(2026).add(const Duration(seconds: 5)),
      ]);
      expect(
          scheduler.now(), DateTime.utc(2026).add(const Duration(seconds: 10)));
    });

    test('honours a timer cancelled by an earlier callback', () {
      final scheduler = FakeFenceScheduler();
      final fired = <String>[];

      late final FenceTimerHandle second;
      scheduler.timer(const Duration(seconds: 1), () {
        fired.add('first');
        second.cancel();
      });
      second = scheduler.timer(const Duration(seconds: 2), () {
        fired.add('second');
      });

      scheduler.elapse(const Duration(seconds: 5));

      expect(fired, ['first']);
      expect(scheduler.hasPendingTimers, isFalse);
    });
  });

  group('GuardedOperation clock injection', () {
    test('uses an explicitly supplied clock for timeline timestamps', () async {
      final scheduler = FakeFenceScheduler(initialTime: DateTime.utc(2026));
      final timeline = Timeline();
      final operation = GuardedOperation<int>(
        name: 'op',
        policy: OperationPolicy.latestWins,
        scheduler: scheduler,
        clock: const _FixedClock(),
        timeline: timeline,
      );

      await operation.run(() async => 1);

      expect(
        timeline.events.map((e) => e.timestamp).toSet(),
        {_FixedClock.instant},
      );
      operation.dispose();
    });
  });

  group('TransitionRule', () {
    test('stores metadata unmodifiably', () {
      final metadata = <String, Object?>{'note': 'original'};
      final rule = allow<int, String>(metadata: metadata);

      metadata['note'] = 'mutated';

      expect(rule.metadata, {'note': 'original'});
      expect(() => rule.metadata!['note'] = 'again', throwsUnsupportedError);
    });

    test('describes itself with and without a name', () {
      expect(allow<int, String>().toString(), 'TransitionRule(int -> String)');
      expect(
        allow<int, String>(name: 'promote').toString(),
        'TransitionRule(promote: int -> String)',
      );
    });
  });
}

final class _FixedClock implements FenceClock {
  const _FixedClock();

  static final DateTime instant = DateTime.utc(1999, 12, 31);

  @override
  DateTime now() => instant;
}
