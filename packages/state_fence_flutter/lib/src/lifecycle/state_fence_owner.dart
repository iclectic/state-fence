import 'package:flutter/foundation.dart';
import 'package:state_fence/state_fence.dart';

/// A lifecycle owner that registers [Disposable] resources such as
/// [StateFence] and [GuardedOperation] and disposes them together.
///
/// Use this directly when you want explicit ownership without a [State] mixin,
/// for example inside a controller or view model. Call [dispose] exactly once
/// when the owner is no longer needed.
class StateFenceOwner implements Disposable {
  final List<Disposable> _owned = [];
  bool _disposed = false;

  /// Whether this owner has been disposed.
  @override
  bool get isDisposed => _disposed;

  /// Registers [resource] for disposal and returns it unchanged.
  ///
  /// This lets call sites stay fluent:
  /// ```dart
  /// final fence = owner.register(StateFence<...>(...));
  /// ```
  ///
  /// Throws a [StateError] if this owner has already been disposed.
  T register<T extends Disposable>(T resource) {
    if (_disposed) {
      throw StateError('StateFenceOwner has been disposed.');
    }
    _owned.add(resource);
    return resource;
  }

  /// Disposes every registered resource, in reverse registration order.
  ///
  /// Subsequent calls are no-ops. Disposal errors from individual resources
  /// are captured and reported via [FlutterError.reportError] so that one
  /// failing resource does not prevent the rest from being disposed.
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final resource in _owned.reversed) {
      try {
        resource.dispose();
      } catch (error, stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'state_fence_flutter',
            context: ErrorDescription(
              'Disposing ${resource.runtimeType} in StateFenceOwner.',
            ),
          ),
        );
      }
    }
    _owned.clear();
  }
}
