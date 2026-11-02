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

  Future<void> _pay() async {
    _apply(fence.transition(const Submitting()));
    final OperationOutcome<String> outcome = await pay.run(
      () async => 'receipt-1',
    );
    switch (outcome) {
      case OperationSuccess(:final String value):
        _apply(fence.transition(Paid(value)));
      case OperationFailure(:final Object error):
        _apply(fence.transition(Failed('$error')));
      case OperationTimedOut(:final Duration timeout):
        _apply(fence.transition(Failed('Timed out after $timeout.')));
      case OperationIgnoredAsStale():
      case OperationIgnoredAsDuplicate():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text('$_ui'),
        GestureDetector(
          onTap: _pay,
          child: const Text('Pay'),
        ),
      ],
    );
  }
}
```

`allow<F, T>()` does not enforce the state-domain bound at compile time. Rules are checked at transition time by runtime type.

`_ui` changes only inside the `TransitionAccepted` branch. A rejection leaves it as it is.

## StateFenceOwner

Use `StateFenceOwner` directly when a controller, rather than a `State`, owns the fence. Call `dispose` once when that controller is finished. `register` throws if the owner has already been disposed.

```dart
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

void main() {
  final StateFenceOwner owner = StateFenceOwner();
  final fence = owner.register(
    StateFence<CheckoutState>(
      name: 'checkout',
      initialState: const Idle(),
      rules: [allow<Idle, Submitting>()],
      reporter: const FlutterErrorReporter(),
    ),
  );
  fence.transition(const Submitting());
  owner.dispose();
}
```

## FlutterErrorReporter

`FlutterErrorReporter` forwards each `StateFenceViolation` to `FlutterError.reportError` as a `StateFenceViolationException`. Pass it when a debug build should show violations in Flutter's error console. The checkout example keeps the scripted rejection, stuck state and timeout on the inspector, so that demo does not look like a crash.

## Build mode

`stateFenceReporterForBuildMode` returns `FlutterErrorReporter` for debug and profile, and `DevNullReporter` for release. Profile is included because `kReleaseMode` is false there. Stack traces stay off unless the caller sets `captureStackTrace` on the fence. Pass `release: true` or `release: false` in tests. The core package does not import Flutter or `dart:developer`.

```dart
import 'package:state_fence/state_fence.dart';
import 'package:state_fence_flutter/state_fence_flutter.dart';

sealed class PayState {
  const PayState();
}

final class Idle extends PayState {
  const Idle();
}

final class Paid extends PayState {
  const Paid();
}

void main() {
  final fence = StateFence<PayState>(
    name: 'pay',
    initialState: const Idle(),
    rules: [allow<Idle, Paid>()],
    reporter: stateFenceReporterForBuildMode(),
  );
  fence.transition(const Paid());
  fence.dispose();
}
```

## Inspector

`StateFenceInspector` shows a timeline and a list of violations you already collected. Rebuild it when those change. It does not register a global listener, and it does not send data anywhere.

```dart
import 'package:flutter/widgets.dart';
import 'package:state_fence/state_fence.dart';
import 'package:state_fence_flutter/state_fence_flutter.dart';

class PayInspector extends StatelessWidget {
  PayInspector({super.key});

  final Timeline timeline = Timeline(capacity: 16);

  @override
  Widget build(BuildContext context) {
    return StateFenceInspector(timeline: timeline);
  }
}
```

The checkout screen in the example uses this widget. The other screens keep a private diagnostics panel.

## ChangeNotifier

`example/lib/change_notifier_checkout.dart` is application code. A `ChangeNotifier` holds the fence and calls `notifyListeners` only when the transition is accepted. Adapter packages for Provider, Riverpod and BLoC live in their own packages and are not imported by this sample.

## Run the example

The example application is `packages/state_fence_flutter/example`. The checkout screen runs a `GuardedOperation` and applies `OperationSuccess`, `OperationFailure` and `OperationTimedOut` through `StateFence.transition`. It leaves the displayed state unchanged for `OperationIgnoredAsStale` and `OperationIgnoredAsDuplicate`, and it shows a rejected transition, a stuck-state violation, a redacted timeline and a `StateFenceInspector`. A ChangeNotifier screen sits beside it. The stale search, duplicate submission and stuck loading screens are still there.

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
