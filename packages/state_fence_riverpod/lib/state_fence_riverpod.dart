/// A Riverpod [Notifier] mixin for [StateFence].
///
/// The core package stays free of a Riverpod dependency. Mix
/// [StateFenceNotifierMixin] onto a `Notifier` and call `attachFence` from
/// `build`.
library;

import 'package:riverpod/riverpod.dart';
import 'package:state_fence/state_fence.dart';

export 'src/state_fence_notifier_mixin.dart';
