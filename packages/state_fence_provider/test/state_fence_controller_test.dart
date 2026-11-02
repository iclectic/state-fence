import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:state_fence/state_fence.dart';
import 'package:state_fence_provider/state_fence_provider.dart';

sealed class PayState {
  const PayState();
}

final class Idle extends PayState {
  const Idle();
}

final class Paid extends PayState {
  const Paid();
}

void main() {
  test('dispose releases the fence', () {
    final StateFenceController<PayState> controller =
        StateFenceController<PayState>(
      name: 'pay',
      initialState: const Idle(),
      rules: <TransitionRule>[allow<Idle, Paid>()],
    );
    final StateFence<PayState> fence = controller.fence;
    controller.dispose();
    expect(fence.isDisposed, isTrue);
  });

  testWidgets('notifies listeners only when the fence accepts', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: stateFenceProvider<PayState>(
          create: (BuildContext context) => StateFenceController<PayState>(
            name: 'pay',
            initialState: const Idle(),
            rules: <TransitionRule>[allow<Idle, Paid>()],
          ),
          child: const _PayView(),
        ),
      ),
    );

    expect(find.text('Idle'), findsOneWidget);
    await tester.tap(find.text('Pay'));
    await tester.pump();
    expect(find.text('Paid'), findsOneWidget);

    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('Idle'), findsNothing);
  });
}

class _PayView extends StatelessWidget {
  const _PayView();

  @override
  Widget build(BuildContext context) {
    final StateFenceController<PayState> controller =
        context.watch<StateFenceController<PayState>>();
    final String label = controller.state is Paid ? 'Paid' : 'Idle';
    return Column(
      children: <Widget>[
        Text(label),
        TextButton(
          onPressed: () => controller.transition(const Paid()),
          child: const Text('Pay'),
        ),
        TextButton(
          onPressed: () => controller.transition(const Idle()),
          child: const Text('Reset'),
        ),
      ],
    );
  }
}
