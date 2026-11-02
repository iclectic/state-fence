import 'package:flutter/widgets.dart';

import 'state_fence_owner.dart';

/// A mixin for [State] that provides a [StateFenceOwner] bound to the
/// [State]'s lifecycle.
///
/// Fences and operations registered through [fenceOwner] are automatically
/// disposed when the [State] is disposed. This makes post-dispose updates
/// visible as violations rather than silent state changes.
///
/// ```dart
/// class PayScreenState extends State<PayScreen> with StateFenceStateMixin {
///   late final StateFence<int> fence = fenceOwner.register(
///     StateFence<int>(
///       name: 'pay',
///       initialState: 0,
///       rules: [allow<int, int>()],
///     ),
///   );
/// }
/// ```
mixin StateFenceStateMixin<T extends StatefulWidget> on State<T> {
  StateFenceOwner? _owner;

  /// The [StateFenceOwner] for this [State].
  ///
  /// The owner is created lazily and disposed automatically when the [State]
  /// is disposed. Register fences and operations through this owner so they
  /// are cleaned up together.
  StateFenceOwner get fenceOwner => _owner ??= StateFenceOwner();

  @override
  void dispose() {
    _owner?.dispose();
    _owner = null;
    super.dispose();
  }
}
