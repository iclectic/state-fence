import 'package:state_fence/state_fence.dart';
import 'package:state_fence_bloc/state_fence_bloc.dart';

sealed class PayState {
  const PayState();
}

final class Idle extends PayState {
  const Idle();
}

final class Paid extends PayState {
  const Paid();
}

Future<void> main() async {
  final StateFenceCubit<PayState> cubit = StateFenceCubit<PayState>(
    name: 'pay',
    initialState: const Idle(),
    rules: <TransitionRule>[allow<Idle, Paid>()],
  );
  final TransitionResult<PayState> rejected = cubit.transition(const Idle());
  if (rejected is! TransitionRejected<PayState>) {
    throw StateError('Idle to Idle must be rejected.');
  }
  final TransitionResult<PayState> accepted = cubit.transition(const Paid());
  if (accepted is! TransitionAccepted<PayState>) {
    throw StateError('Idle to Paid must be accepted.');
  }
  await cubit.close();
}
