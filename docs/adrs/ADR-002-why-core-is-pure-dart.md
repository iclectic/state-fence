# ADR-002: Why the core package is pure Dart

## Status

Accepted

## Context

Flutter-specific packages often pull in the full Flutter SDK. This makes them harder to use in command-line tools, server-side Dart or package tests that should run on a Dart VM only. It also increases the dependency surface for package authors.

## Decision

The `state_fence` package will be pure Dart and will not import Flutter. Flutter-specific lifecycle bindings will live in `state_fence_flutter`.

## Consequences

- `state_fence` can be tested and used without a Flutter device or `flutter test`.
- The test utilities in `state_fence_test` can run on the Dart VM.
- `state_fence_flutter` depends on `state_fence` and adds Flutter-specific mixins, reporters and inspector helpers.
- The core package must avoid `BuildContext`, `Widget`, `ChangeNotifier` and other Flutter types.
