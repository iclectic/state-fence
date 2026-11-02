# StateFence example

An interactive Flutter application that demonstrates StateFence.

- Checkout contract: a `StateFence` and a `GuardedOperation` in one flow.
  Success, failure and timeout are applied through `transition`. Stale and
  duplicate outcomes leave the displayed state unchanged. The diagnostics
  panel shows the rejection, the stuck-state violation and the redacted
  timeline.
- Stale search response, resolved with `OperationPolicy.latestWins`.
- Duplicate submission, resolved with `OperationPolicy.firstWins`.
- Stuck loading state, resolved with a `GuardedOperation` timeout.

The checkout screen registers its fence and operations with
`StateFenceStateMixin` and reports violations through `FlutterErrorReporter`
as well as the on-screen panel.

## Running

The demo UI needs Flutter >=3.27.0. The `state_fence_flutter` library itself
allows >=3.16.0.

```sh
flutter pub get
flutter run
```

To run in a browser:

```sh
flutter run -d chrome
```

In this repository, `pubspec_overrides.yaml` resolves the sibling packages.
That file is omitted from the published archive.
