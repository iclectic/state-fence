import 'package:flutter/foundation.dart';
import 'package:state_fence/state_fence.dart';

/// A lifecycle owner that registers [StateFence] and [GuardedOperation]
/// instances and disposes them together.
///
/// Use this directly when you want explicit ownership without a [State] mixin,
/// for example inside a controller or view model. Call [dispose] exactly once
/// when the owner is no longer needed.
class StateFenceOwner {
  final List<dynamic> _owned = [];
  bool _disposed = false;

  /// Whether this owner has been disposed.
  bool get isDisposed => _disposed;

  /// Registers [fence] for disposal and returns it unchanged.
  ///
  /// This lets call sites stay fluent:
  /// ```dart
  /// final fence = owner.register(StateFence<...>(...));
  /// ```
  T register<T>(T resource) {
    if (_disposed) {
      throw StateError('StateFenceOwner has been disposed.');
    }
    if (resource is! StateFence && resource is! GuardedOperation) {
      throw ArgumentError(
        'StateFenceOwner can only register StateFence or GuardedOperation '
        'instances, got ${resource.runtimeType}.',
      );
    }
    _owned.add(resource);
    return resource;
  }

  /// Disposes every registered fence and operation.
  ///
  /// Subsequent calls are no-ops. Disposal errors from individual resources
  /// are captured and reported via [FlutterError.reportError] so that one
  /// failing resource does not prevent the rest from being disposed.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final resource in _owned.reversed) {
      try {
        if (resource is StateFence) {
          resource.dispose();
        } else if (resource is GuardedOperation) {
          resource.dispose();
        }
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
