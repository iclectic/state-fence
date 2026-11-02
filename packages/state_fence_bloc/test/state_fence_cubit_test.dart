import 'package:state_fence/state_fence.dart';
import 'package:state_fence_bloc/state_fence_bloc.dart';
import 'package:test/test.dart';

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
  test('emits only when the fence accepts', () async {
    final List<PayState> seen = <PayState>[];
    final StateFenceCubit<PayState> cubit = StateFenceCubit<PayState>(
      name: 'pay',
      initialState: const Idle(),
      rules: <TransitionRule>[allow<Idle, Paid>()],
    );
    final subscription = cubit.stream.listen(seen.add);

    expect(
      cubit.transition(const Paid()),
      isA<TransitionAccepted<PayState>>(),
    );
    expect(cubit.state, isA<Paid>());

    expect(
      cubit.transition(const Idle()),
      isA<TransitionRejected<PayState>>(),
    );
    expect(cubit.state, isA<Paid>());
    await Future<void>.delayed(Duration.zero);
    expect(seen, hasLength(1));
    expect(seen.single, isA<Paid>());

    await subscription.cancel();
    await cubit.close();
    expect(cubit.fence.isDisposed, isTrue);
  });
}
