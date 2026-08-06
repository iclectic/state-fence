# StateFence

Catch dangerous state transitions before your users do.

StateFence is a state-management-neutral correctness toolkit for Dart and Flutter. It validates state transitions, guards asynchronous operations against race conditions and records privacy-aware diagnostics. It does not replace your existing state-management solution; it sits beside it.

## Packages

- `packages/state_fence` — Pure Dart core. Transition rules, guarded operations, diagnostics and redaction.
- `packages/state_fence_flutter` — Flutter integration for lifecycle ownership and optional development helpers.
- `packages/state_fence_test` — Test matchers, fake clock support and scenario helpers.

## Status

This repository is at the foundation and design-review stage. The product brief, API proposal and architecture decision records live under `docs/`. Phase 2 will implement transition contracts after the provisional API is reviewed.

## Repository Commands

```sh
# Format all packages
dart format --set-exit-if-changed packages

# Analyse the pure Dart packages
dart analyze packages/state_fence
dart analyze packages/state_fence_test

# Analyse the Flutter package
flutter analyze packages/state_fence_flutter

# Run tests
cd packages/state_fence && dart test
cd packages/state_fence_flutter && flutter test
cd packages/state_fence_test && dart test
```

See `AGENTS.md` for the full development guide.
