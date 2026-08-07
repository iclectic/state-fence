import 'package:state_fence/state_fence.dart';
import 'package:test/test.dart';

sealed class _SearchState {
  const _SearchState();
}

final class _Idle extends _SearchState {
  const _Idle();
}

final class _Loading extends _SearchState {
  const _Loading();
}

void main() {
  test('state_fence transition contracts load and run', () {
    final fence = StateFence<_SearchState>(
      name: 'search',
      initialState: const _Idle(),
      rules: [
        allow<_Idle, _Loading>(),
      ],
    );

    final result = fence.transition(const _Loading());

    expect(result, isA<TransitionAccepted<_SearchState>>());
    expect(fence.current, isA<_Loading>());
  });
}
