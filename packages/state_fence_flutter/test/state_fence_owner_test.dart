import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:state_fence/state_fence.dart';
import 'package:state_fence_flutter/state_fence_flutter.dart';

void main() {
  group('StateFenceOwner', () {
    test('registers and disposes a StateFence', () {
      final owner = StateFenceOwner();
      final fence = owner.register(
        StateFence<String>(
          name: 'test',
          initialState: 'idle',
          rules: [allow<String, int>()],
        ),
      );

      expect(fence.isDisposed, isFalse);
      owner.dispose();
      expect(fence.isDisposed, isTrue);
    });

    test('registers and disposes a GuardedOperation', () {
      final owner = StateFenceOwner();
      final op = owner.register(
        GuardedOperation<int>(
          name: 'op',
          policy: OperationPolicy.latestWins,
        ),
      );

      expect(op.isDisposed, isFalse);
      owner.dispose();
      expect(op.isDisposed, isTrue);
    });

    test('dispose is idempotent', () {
      final owner = StateFenceOwner();
      owner.register(
        StateFence<String>(
          name: 'test',
          initialState: 'idle',
          rules: [],
        ),
      );

      owner.dispose();
      owner.dispose(); // should not throw
      expect(owner.isDisposed, isTrue);
    });

    test('register after dispose throws StateError', () {
      final owner = StateFenceOwner();
      owner.dispose();

      expect(
        () => owner.register(
          StateFence<String>(
            name: 'late',
            initialState: 'idle',
            rules: [],
          ),
        ),
        throwsStateError,
      );
    });

    test('register accepts any Disposable and disposes it', () {
      final owner = StateFenceOwner();
      final resource = _FakeDisposable();

      owner.register<Disposable>(resource);
      owner.dispose();

      expect(resource.isDisposed, isTrue);
    });
  });

  group('StateFenceStateMixin', () {
    testWidgets('disposes registered fences on widget disposal',
        (tester) async {
      late StateFence<String>? capturedFence;

      await tester.pumpWidget(
        _TestWidget(
          onInit: (fence) => capturedFence = fence,
        ),
      );

      expect(capturedFence, isNotNull);
      expect(capturedFence!.isDisposed, isFalse);

      // Replace the widget to trigger disposal.
      await tester.pumpWidget(const SizedBox());

      expect(capturedFence!.isDisposed, isTrue);
    });

    testWidgets('fenceOwner is accessible during build', (tester) async {
      await tester.pumpWidget(const _TestWidget());

      // The widget renders a Text showing the fence name.
      expect(find.text('test-fence'), findsOneWidget);
    });
  });

  group('FlutterErrorReporter', () {
    test('forwards violations to FlutterError.reportError', () {
      FlutterErrorDetails? captured;
      final originalHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        captured = details;
      };

      try {
        const reporter = FlutterErrorReporter();
        final violation = TransitionViolation(
          source: 'test',
          previousState: String,
          attemptedState: int,
          timestamp: DateTime(2026, 1, 1),
          reason: 'Test violation',
        );

        reporter.report(violation);

        expect(captured, isNotNull);
        expect(captured!.exception, isA<StateFenceViolationException>());
        final exception = captured!.exception as StateFenceViolationException;
        expect(exception.violation, same(violation));
      } finally {
        FlutterError.onError = originalHandler;
      }
    });
  });
}

class _FakeDisposable implements Disposable {
  bool _disposed = false;

  @override
  bool get isDisposed => _disposed;

  @override
  void dispose() => _disposed = true;
}

class _TestWidget extends StatefulWidget {
  final void Function(StateFence<String> fence)? onInit;

  const _TestWidget({this.onInit});

  @override
  State<_TestWidget> createState() => _TestWidgetState();
}

class _TestWidgetState extends State<_TestWidget> with StateFenceStateMixin {
  late final StateFence<String> fence;

  @override
  void initState() {
    super.initState();
    fence = fenceOwner.register(
      StateFence<String>(
        name: 'test-fence',
        initialState: 'idle',
        rules: [allow<String, String>()],
      ),
    );
    widget.onInit?.call(fence);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(body: Text(fence.name)),
    );
  }
}
