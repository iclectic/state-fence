# state_fence_provider

A Provider adapter for `state_fence`.

`StateFenceController` is a `ChangeNotifier`. It notifies listeners only when `transition` is accepted. `stateFenceProvider` puts that controller in the tree. The core package does not depend on Flutter or Provider. A ChangeNotifier sample that does not use this package lives in the `state_fence_flutter` example.

## Install

```yaml
dependencies:
  state_fence: ^0.1.0
  state_fence_provider: ^0.1.0
```

In the StateFence repository, `pubspec_overrides.yaml` resolves the sibling core. That file is excluded from the published archive.

The library allows Flutter `>=3.16.0`.

## Use

```dart
import 'package:flutter/widgets.dart';
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

class PayView extends StatelessWidget {
  const PayView({super.key});

  @override
  Widget build(BuildContext context) {
    final StateFenceController<PayState> controller =
        context.watch<StateFenceController<PayState>>();
    final String label = controller.state is Paid ? 'Paid' : 'Idle';
    return Column(
      children: <Widget>[
        Text(label),
        GestureDetector(
          onTap: () => controller.transition(const Paid()),
          child: const Text('Pay'),
        ),
      ],
    );
  }
}

class PayApp extends StatelessWidget {
  const PayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return stateFenceProvider<PayState>(
      create: (_) => StateFenceController<PayState>(
        name: 'pay',
        initialState: const Idle(),
        rules: [allow<Idle, Paid>()],
      ),
      child: const PayView(),
    );
  }
}
```

`allow<F, T>()` does not enforce the state-domain bound at compile time. Rules are checked at transition time by runtime type.

`context.watch` comes from `package:provider/provider.dart`. Call `transition` from the controller. The widget rebuilds when the fence accepts.

## Licence

MIT. See `LICENSE`.
