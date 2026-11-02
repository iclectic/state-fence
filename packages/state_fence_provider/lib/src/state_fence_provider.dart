import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'state_fence_controller.dart';

/// Builds a [ChangeNotifierProvider] for a [StateFenceController].
///
/// Listen with `context.watch<StateFenceController<S>>()` and call
/// [StateFenceController.transition]. Listeners rebuild only after an
/// accepted transition.
ChangeNotifierProvider<StateFenceController<S>> stateFenceProvider<S>({
  Key? key,
  required Create<StateFenceController<S>> create,
  Widget? child,
}) {
  return ChangeNotifierProvider<StateFenceController<S>>(
    key: key,
    create: create,
    child: child,
  );
}
