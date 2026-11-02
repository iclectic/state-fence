/// A Cubit adapter for [StateFence].
///
/// The core package does not depend on `bloc`. This package depends on the
/// core and emits only when a transition is accepted.
library;

import 'package:state_fence/state_fence.dart';

export 'src/state_fence_cubit.dart';
