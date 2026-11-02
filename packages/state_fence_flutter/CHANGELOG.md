# Changelog

All notable changes to `state_fence_flutter` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.1.0

### Added

- `StateFenceOwner` for explicit lifecycle ownership of fences and operations.
- `StateFenceStateMixin` for automatic disposal on `State.dispose`.
- `FlutterErrorReporter` forwarding violations to `FlutterError.reportError`.
- `stateFenceReporterForBuildMode`, which uses `FlutterErrorReporter` in debug and profile and `DevNullReporter` in release.
- `StateFenceInspector`, an opt-in on-device view of a timeline and caller-supplied violations. It does not send data anywhere.
- `StateFenceViolationException` wrapping violations for Flutter's error pipeline.
- Example application with a checkout screen that applies guarded outcomes through a `StateFence`, a ChangeNotifier sample, plus the stale search, duplicate submission and stuck loading scenarios.
- Screenshots of the example, wired in `pubspec.yaml`.
- Widget and unit tests covering ownership, disposal, mixin integration, reporter forwarding, build-mode selection and the inspector.
