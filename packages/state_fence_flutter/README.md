# state_fence_flutter

Flutter integration for StateFence.

`state_fence_flutter` disposes a `StateFence` and a `GuardedOperation` with the `State` that owns them, and can forward violations to `FlutterError.reportError`. Transition rules, concurrency policies and the timeline stay in `state_fence`. This package does not rebuild widgets.

## Install

```yaml
dependencies:
  state_fence: ^0.1.0
  state_fence_flutter: ^0.1.0
```

Use these coordinates once the packages are published. In the StateFence repository, `pubspec_overrides.yaml` resolves `state_fence` from the sibling core package. That file is excluded from the published archive.

The library allows Flutter `>=3.16.0`.

## StateFenceStateMixin

Mix `StateFenceStateMixin` into a `State`. `fenceOwner` is a `StateFenceOwner` created for that `State`. `register` keeps a `StateFence` or a `GuardedOperation` and disposes it when the `State` is disposed.

Call `transition` yourself. Assign widget state only when the result is `TransitionAccepted`. Pass `FlutterErrorReporter` when a debug build should show rejections, timeouts and stuck states in Flutter's error console. The default reporter in `state_fence` is silent.

```dart
import 'package:flutter/widgets.dart';
import 'package:state_fence/state_fence.dart';
import 'package:state_fence_flutter/state_fence_flutter.dart';

sealed class CheckoutState {
  const CheckoutState();
}

final class Idle extends CheckoutState {
  const Idle();
}

final class Submitting extends CheckoutState {
  const Submitting();
}

final class Paid extends CheckoutState {
  const Paid(this.receipt);
  final String receipt;
}

final class Failed extends CheckoutState {
  const Failed(this.message);
  final String message;
}

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen>
    with StateFenceStateMixin {
  late final StateFence<CheckoutState> fence = fenceOwner.register(
    StateFence<CheckoutState>(
      name: 'checkout',
      initialState: const Idle(),
      rules: [
        allow<Idle, Submitting>(),
        allow<Submitting, Paid>(),
        allow<Submitting, Failed>(),
        allow<Failed, Submitting>(),
      ],
      reporter: const FlutterErrorReporter(),
    ),
  );

  late final GuardedOperation<String> pay = fenceOwner.register(
    GuardedOperation<String>(
      name: 'pay',
      policy: OperationPolicy.firstWins,
      reporter: const FlutterErrorReporter(),
    ),
  );

  CheckoutState _ui = const Idle();

  void _apply(TransitionResult<CheckoutState> result) {
    if (result case TransitionAccepted(:final state)) {
      setState(() => _ui = state);
    }
  }
}
```

`_ui` changes only inside the `TransitionAccepted` branch. A rejection leaves it as it is.

## StateFenceOwner

Use `StateFenceOwner` directly when a controller, rather than a `State`, owns the fence. Call `dispose` once when that controller is finished. `register` throws if the owner has already been disposed.

```dart
final StateFenceOwner owner = StateFenceOwner();

final fence = owner.register(
  StateFence<CheckoutState>(
    name: 'checkout',
    initialState: const Idle(),
    rules: [allow<Idle, Submitting>()],
    reporter: const FlutterErrorReporter(),
  ),
);

owner.dispose();
```

## FlutterErrorReporter

`FlutterErrorReporter` forwards each `StateFenceViolation` to `FlutterError.reportError` as a `StateFenceViolationException`. The example uses it together with a collecting reporter so the same violation appears in the Flutter error console and in the on-screen diagnostics panel.

## Run the example

The example application is `packages/state_fence_flutter/example`. The checkout screen runs a `GuardedOperation` and applies `OperationSuccess`, `OperationFailure` and `OperationTimedOut` through `StateFence.transition`. It leaves the displayed state unchanged for `OperationIgnoredAsStale` and `OperationIgnoredAsDuplicate`, and it shows a rejected transition, a stuck-state violation and a redacted timeline. The stale search, duplicate submission and stuck loading screens are still there.

From a clone of this repository:

```sh
cd packages/state_fence_flutter/example
flutter pub get
flutter run
flutter run -d chrome
```

The clone's `example/pubspec_overrides.yaml` points at the sibling packages. A published archive omits that file, so the same commands from a pub-cache checkout resolve `state_fence` and `state_fence_flutter` from pub.dev.

The example needs Flutter `>=3.27.0` because the demo UI uses `Color.withValues` and the `surfaceContainer` colour roles. The library itself allows Flutter `>=3.16.0`. An older Flutter SDK can depend on `state_fence_flutter` and still fail to compile this demo.

## Licence

MIT. See `LICENSE`.
