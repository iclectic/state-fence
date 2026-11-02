import 'package:riverpod/riverpod.dart';
import 'package:state_fence/state_fence.dart';
import 'package:state_fence_riverpod/state_fence_riverpod.dart';
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

class PayNotifier extends Notifier<PayState>
    with StateFenceNotifierMixin<PayState> {
  @override
  PayState build() {
    const Idle initial = Idle();
    attachFence(
      name: 'pay',
      initialState: initial,
      rules: <TransitionRule>[allow<Idle, Paid>()],
    );
    return initial;
  }
}

final NotifierProvider<PayNotifier, PayState> payProvider =
    NotifierProvider<PayNotifier, PayState>(PayNotifier.new);

void main() {
  test('assigns state only when the fence accepts', () {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(payProvider), isA<Idle>());
    final PayNotifier notifier = container.read(payProvider.notifier);

    expect(
      notifier.transition(const Paid()),
      isA<TransitionAccepted<PayState>>(),
    );
    expect(container.read(payProvider), isA<Paid>());

    expect(
      notifier.transition(const Idle()),
      isA<TransitionRejected<PayState>>(),
    );
    expect(container.read(payProvider), isA<Paid>());
  });

  test('disposes the fence with the provider', () {
    final ProviderContainer container = ProviderContainer();
    final StateFence<PayState> fence =
        container.read(payProvider.notifier).fence;

    container.dispose();
    expect(fence.isDisposed, isTrue);
  });
}
