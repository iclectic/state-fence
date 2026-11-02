# state_fence_riverpod

A Riverpod adapter for `state_fence`.

Mix `StateFenceNotifierMixin` onto a `Notifier`. Call `attachFence` from `build`. `transition` assigns `state` only when the fence accepts the next value. The fence is disposed with the provider. `state_fence` does not depend on Riverpod.

## Install

```yaml
dependencies:
  state_fence: ^0.1.0
  state_fence_riverpod: ^0.1.0
```

In the StateFence repository, `pubspec_overrides.yaml` resolves the sibling core. That file is excluded from the published archive.

This package depends on `riverpod` 2.x and the `Notifier` API. A Flutter app can depend on `flutter_riverpod` as well. The mixin itself does not import Flutter.

## Use

```dart
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
    const initial = Idle();
    attachFence(
      name: 'pay',
      initialState: initial,
      rules: [allow<Idle, Paid>()],
    );
    return initial;
  }
}

final payProvider = NotifierProvider<PayNotifier, PayState>(PayNotifier.new);

void markPaid(Ref ref) {
  ref.read(payProvider.notifier).transition(const Paid());
}
```

`allow<F, T>()` does not enforce the state-domain bound at compile time. Rules are checked at transition time by runtime type.

Use `GuardedOperation` from `state_fence` for asynchronous work, and call `transition` only for outcomes that may change state.

## Licence

MIT. See `LICENSE`.
