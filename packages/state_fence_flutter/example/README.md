# StateFence example

An interactive Flutter application that demonstrates StateFence against three
common state failures:

- Stale search response, resolved with `OperationPolicy.latestWins`.
- Duplicate submission, resolved with `OperationPolicy.firstWins`.
- Stuck loading state, resolved with a `GuardedOperation` timeout.

Each screen frames the failure mode, lets you trigger it and shows the guarded
outcome alongside a live diagnostics panel of violations and timeline events.

## Running

```sh
flutter pub get
flutter run
```

To run in a browser:

```sh
flutter run -d chrome
```
