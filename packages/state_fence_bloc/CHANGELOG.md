# Changelog

All notable changes to `state_fence_bloc` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.1.0

### Added

- `StateFenceCubit<S>`, a `Cubit` that emits only when its `StateFence` accepts the transition and disposes the fence on `close`.
