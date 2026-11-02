/// StateFence Flutter integration.
///
/// Provides lifecycle ownership for [StateFence] and [GuardedOperation]
/// instances, a [FlutterErrorReporter] that forwards violations into Flutter's
/// error pipeline, [stateFenceReporterForBuildMode] for debug, profile and
/// release defaults, and an opt-in [StateFenceInspector].
library;

import 'package:state_fence/state_fence.dart';

export 'src/inspector/state_fence_inspector.dart';
export 'src/lifecycle/state_fence_owner.dart';
export 'src/lifecycle/state_fence_state_mixin.dart';
export 'src/reporting/build_mode_reporter.dart';
export 'src/reporting/flutter_error_reporter.dart';
