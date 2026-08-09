# Changelog

All notable changes to `state_fence_flutter` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.1.0

### Added

- `StateFenceOwner` for explicit lifecycle ownership of fences and operations.
- `StateFenceStateMixin` for automatic disposal on `State.dispose`.
- `FlutterErrorReporter` forwarding violations to `FlutterError.reportError`.
- `StateFenceViolationException` wrapping violations for Flutter's error pipeline.
- Example application with three failure scenarios: stale search, duplicate submission and stuck loading.
- 9 widget and unit tests covering ownership, disposal, mixin integration and reporter forwarding.
