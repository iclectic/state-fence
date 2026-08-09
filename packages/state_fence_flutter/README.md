# state_fence_flutter

Flutter integration for StateFence.

Provides lifecycle ownership for `StateFence` and `GuardedOperation` instances, plus a `FlutterErrorReporter` that forwards violations into Flutter's standard error reporting pipeline.

## Quick Start

```dart
class _MyScreenState extends State<MyScreen> with StateFenceStateMixin {
  late final fence = fenceOwner.register(
    StateFence<MyState>(name: 'my', initialState: ..., rules: [...]),
  );

  // fenceOwner.dispose() is called automatically when the State is disposed.
}
```

See the [main README](../../README.md) for full documentation.
