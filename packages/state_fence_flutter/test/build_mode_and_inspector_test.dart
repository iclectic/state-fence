import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_fence/state_fence.dart';
import 'package:state_fence_flutter/state_fence_flutter.dart';

void main() {
  group('stateFenceReporterForBuildMode', () {
    test('uses FlutterErrorReporter when release is false', () {
      expect(
        stateFenceReporterForBuildMode(release: false),
        isA<FlutterErrorReporter>(),
      );
    });

    test('uses DevNullReporter when release is true', () {
      expect(
        stateFenceReporterForBuildMode(release: true),
        isA<DevNullReporter>(),
      );
    });

    test('follows kReleaseMode when release is omitted', () {
      final StateFenceReporter reporter = stateFenceReporterForBuildMode();
      expect(
        reporter,
        kReleaseMode ? isA<DevNullReporter>() : isA<FlutterErrorReporter>(),
      );
    });

    test('honours caller supplied reporters', () {
      const StateFenceReporter debug = DevNullReporter();
      const StateFenceReporter release = FlutterErrorReporter();

      expect(
        stateFenceReporterForBuildMode(release: false, debugReporter: debug),
        same(debug),
      );
      expect(
        stateFenceReporterForBuildMode(
          release: true,
          releaseReporter: release,
        ),
        same(release),
      );
    });
  });

  testWidgets('StateFenceInspector lists a violation and a timeline event', (
    WidgetTester tester,
  ) async {
    final Timeline timeline = Timeline();
    timeline.add(
      OperationStartedEvent(
        source: 'pay',
        timestamp: DateTime(2026, 1, 1),
        token: const OperationToken(1),
      ),
    );
    final TransitionViolation violation = TransitionViolation(
      source: 'pay',
      timestamp: DateTime(2026, 1, 1),
      previousState: Idle,
      attemptedState: Paid,
      reason: 'Idle cannot become Paid.',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StateFenceInspector(
            timeline: timeline,
            violations: <StateFenceViolation>[violation],
          ),
        ),
      ),
    );

    expect(find.text('StateFence inspector'), findsOneWidget);
    expect(find.text('Idle cannot become Paid.'), findsOneWidget);
    expect(find.textContaining('operationStarted'), findsOneWidget);
    expect(find.textContaining('Nothing is sent'), findsOneWidget);
  });
}

/// Placeholder types so the violation can name real runtime types.
final class Idle {}

/// Placeholder paid state for the inspector fixture.
final class Paid {}
