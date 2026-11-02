# state_fence_bloc

A Cubit adapter for `state_fence`.

`StateFenceCubit` holds a `StateFence` and calls `emit` only when `transition` is accepted. A rejection leaves the cubit state unchanged. The core package does not depend on `bloc`. This package depends on the core.

## Install

```yaml
dependencies:
  state_fence: ^0.1.0
  state_fence_bloc: ^0.1.0
```

Publish `state_fence` before this package. In the StateFence repository, `pubspec_overrides.yaml` resolves the sibling core. That file is excluded from the published archive.

## Use

```dart
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

final cubit = StateFenceCubit<PayState>(
  name: 'pay',
  initialState: const Idle(),
  rules: [allow<Idle, Paid>()],
);

cubit.transition(const Paid());
await cubit.close();
```

`close` disposes the fence. Pair the cubit with `GuardedOperation` from `state_fence` when the event handler is asynchronous, and call `transition` only for outcomes that may change state.

## Licence

MIT. See `LICENSE`.
