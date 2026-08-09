import 'package:state_fence/state_fence.dart';

/// A minimal state hierarchy for the search example.
sealed class SearchState {
  const SearchState();
}

final class Idle extends SearchState {
  const Idle();
}

final class Loading extends SearchState {
  const Loading();
}

final class Data extends SearchState {
  const Data(this.results);
  final List<String> results;
}

final class Error extends SearchState {
  const Error(this.message);
  final String message;
}

/// A minimal StateFence example showing transition contracts and
/// guarded operations in a pure Dart console application.
void main() async {
  // 1. Create a fence with allowed transitions.
  final fence = StateFence<SearchState>(
    name: 'search',
    initialState: const Idle(),
    rules: [
      allow<Idle, Loading>(),
      allow<Loading, Data>(),
      allow<Loading, Error>(),
      allow<Error, Loading>(),
    ],
  );

  // 2. Transition to loading.
  final result = fence.transition(const Loading());
  print('Transition to Loading: ${result.runtimeType}');

  // 3. Attempt an illegal transition (Idle to Data).
  final illegal = StateFence<SearchState>(
    name: 'search',
    initialState: const Idle(),
    rules: [allow<Idle, Loading>()],
  ).transition(const Data([]));
  print('Illegal transition: ${illegal.runtimeType}');
  if (illegal case TransitionRejected(:final violation)) {
    print('  Reason: ${violation.reason}');
  }

  // 4. Guard an async operation with latestWins.
  final operation = GuardedOperation<List<String>>(
    name: 'search',
    policy: OperationPolicy.latestWins,
  );

  final slow = operation.run(() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return ['slow result'];
  });

  final fast = operation.run(() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return ['fast result'];
  });

  final fastOutcome = await fast;
  final slowOutcome = await slow;

  print('Fast outcome: ${fastOutcome.runtimeType}');
  print('Slow outcome: ${slowOutcome.runtimeType}');
  if (fastOutcome case OperationSuccess(:final value)) {
    print('  Fast value: $value');
  }
  if (slowOutcome case OperationIgnoredAsStale()) {
    print('  Slow result was correctly discarded as stale.');
  }
}
