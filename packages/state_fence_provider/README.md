# state_fence_provider

A Provider adapter for `state_fence`.

`StateFenceController` is a `ChangeNotifier`. It notifies listeners only when `transition` is accepted. `stateFenceProvider` puts that controller in the tree. The core package does not depend on Flutter or Provider. A ChangeNotifier sample that does not use this package lives in the `state_fence_flutter` example.

## Install

```yaml
dependencies:
  state_fence: ^0.1.0
  state_fence_provider: ^0.1.0
```

Publish `state_fence` before this package. In the StateFence repository, `pubspec_overrides.yaml` resolves the sibling core. That file is excluded from the published archive.

The library allows Flutter `>=3.16.0`.

## Use

```dart
import 'package:flutter/widgets.dart';
import 'package:state_fence/state_fence.dart';
import 'package:state_fence_provider/state_fence_provider.dart';

stateFenceProvider<PayState>(
  create: (_) => StateFenceController<PayState>(
    name: 'pay',
    initialState: const Idle(),
    rules: [allow<Idle, Paid>()],
  ),
  child: const PayView(),
);
```

Read it with `context.watch<StateFenceController<PayState>>()`. Call `transition` from the controller. The widget rebuilds when the fence accepts.

## Licence

MIT. See `LICENSE`.
