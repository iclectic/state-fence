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
/// class _MyScreenState extends State<MyScreen> with StateFenceStateMixin {
///   late final fence = fenceOwner.register(
///     StateFence<MyState>(name: 'my', initialState: ..., rules: [...]),
///   );
///
///   @override
///   void dispose() {
///     // fenceOwner.dispose() is called automatically by the mixin.
///     super.dispose();
///   }
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
