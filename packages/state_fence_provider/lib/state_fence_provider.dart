/// A Provider and [ChangeNotifier] adapter for [StateFence].
///
/// [StateFenceController] notifies listeners only when a transition is
/// accepted. [stateFenceProvider] places that controller in the tree.
/// `state_fence` does not depend on Flutter or Provider.
library;

import 'package:flutter/foundation.dart';
import 'package:state_fence/state_fence.dart';

export 'src/state_fence_controller.dart';
export 'src/state_fence_provider.dart';
