import 'package:flutter/foundation.dart';
import 'package:state_fence/state_fence.dart';

import 'flutter_error_reporter.dart';

/// Selects a [StateFenceReporter] for the current Flutter build mode.
///
/// Debug and profile builds use [debugReporter], which defaults to
/// [FlutterErrorReporter]. Release builds use [releaseReporter], which
/// defaults to [DevNullReporter]. Profile is not a release build:
/// [kReleaseMode] is false in profile, so profile keeps reporting.
///
/// Stack traces stay off unless the caller sets `captureStackTrace` on the
/// fence or operation. This function does not turn them on.
///
/// Pass [release] to force a branch in tests. When it is omitted, the choice
/// follows [kReleaseMode]. The core package does not detect the build mode.
StateFenceReporter stateFenceReporterForBuildMode({
  bool? release,
  StateFenceReporter? debugReporter,
  StateFenceReporter? releaseReporter,
}) {
  final bool isRelease = release ?? kReleaseMode;
  if (isRelease) {
    return releaseReporter ?? const DevNullReporter();
  }
  return debugReporter ?? const FlutterErrorReporter();
}
