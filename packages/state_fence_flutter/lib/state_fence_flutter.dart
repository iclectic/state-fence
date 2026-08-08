/// StateFence Flutter integration.
///
/// Provides lifecycle ownership for [StateFence] and [GuardedOperation]
/// instances, plus a [FlutterErrorReporter] that forwards violations into
/// Flutter's standard error reporting pipeline.
library;

export 'src/lifecycle/state_fence_owner.dart';
export 'src/lifecycle/state_fence_state_mixin.dart';
export 'src/reporting/flutter_error_reporter.dart';
