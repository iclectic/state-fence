import 'package:riverpod/riverpod.dart';
import 'package:state_fence/state_fence.dart';
import 'package:state_fence_riverpod/state_fence_riverpod.dart';

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

Future<void> main() async {
  final ProviderContainer container = ProviderContainer();
  final PayNotifier notifier = container.read(
    NotifierProvider<PayNotifier, PayState>(PayNotifier.new).notifier,
  );
  final TransitionResult<PayState> rejected = notifier.transition(const Idle());
  if (rejected is! TransitionRejected<PayState>) {
    throw StateError('Idle to Idle must be rejected.');
  }
  final TransitionResult<PayState> accepted = notifier.transition(const Paid());
  if (accepted is! TransitionAccepted<PayState>) {
    throw StateError('Idle to Paid must be accepted.');
  }
  container.dispose();
}
