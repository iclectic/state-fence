# Changelog

All notable changes to `state_fence_riverpod` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.1.0

### Added

- `StateFenceNotifierMixin<S>` for a Riverpod `Notifier`. Call `attachFence` from `build`. `transition` assigns `state` only when the fence accepts it, and the fence is disposed with the provider.
