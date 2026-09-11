# AGENTS.md

This file records the repository layout, commands, architecture constraints and definition of done for agents working on StateFence.

## Repository Layout

```
/
├── docs/
│   ├── research/             # Ecosystem review and gap analysis
│   ├── product_brief.md      # Target users, jobs to be done, MVP scope
│   ├── api_proposal.md       # Provisional public API shapes
│   └── adrs/                 # Architecture decision records
├── packages/
│   ├── state_fence/          # Pure Dart core
│   ├── state_fence_flutter/  # Flutter integration
│   └── state_fence_test/     # Test utilities
├── .github/workflows/ci.yml  # Format, analyse and test
├── AGENTS.md                 # This file
└── README.md
```

## Commands

Run all commands from the repository root unless otherwise specified.

```sh
# Format all packages
dart format --set-exit-if-changed packages

# Analyse
dart analyze packages/state_fence
dart analyze packages/state_fence_test
flutter analyze packages/state_fence_flutter

# Test
cd packages/state_fence && dart test
cd packages/state_fence_flutter && flutter test
cd packages/state_fence_test && dart test
```

## Publishing

The three packages depend on each other, so publication order matters.

1. `state_fence` first. Nothing depends on it being published.
2. `state_fence_flutter` and `state_fence_test` once `state_fence` is live on pub.dev, because each declares a hosted `state_fence` constraint.

Local development resolves the sibling core package through `pubspec_overrides.yaml`, never through `dependency_overrides` in `pubspec.yaml`. A relative path override inside a published `pubspec.yaml` cannot be resolved once the archive is extracted on its own, which breaks `dart pub get` for pub.dev analysis and drops the package score. Each `.pubignore` keeps `pubspec_overrides.yaml` out of the archive, and the `publish_readiness` CI job enforces both rules.

Once `state_fence` is published, verify the real archive resolves without the override:

```sh
cd packages/state_fence_test && dart pub get --no-example
```

## Architecture Constraints

- `packages/state_fence` must be pure Dart and must not import Flutter.
- The core package must not depend on a particular state-management framework.
- Public models must be immutable.
- Time, scheduling, reporting and identifier generation must be injectable for deterministic testing.
- Do not automatically serialise arbitrary application state.
- Do not use reflection, code generation, global singletons, telemetry or network calls in the MVP.
- No adapter for Riverpod, BLoC or any other framework until approved for a future phase.

## Documentation Style

- Use British English in prose documentation.
- Do not use em dashes in prose documentation.
- Use `dartdoc` for every public member.
- Keep prose concise and avoid unsupported claims about competitors or package availability.

## Definition of Done

- The change is documented, including `dartdoc` for public APIs.
- `dart format` passes with `--set-exit-if-changed`.
- `dart analyze` or `flutter analyze` passes with no warnings.
- All relevant tests pass.
- The pure Dart package has no Flutter dependency.
- The final diff has been reviewed for accidental public API, dependency and documentation problems.
