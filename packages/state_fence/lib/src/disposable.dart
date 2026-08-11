/// A resource with an explicit disposal lifecycle.
///
/// [StateFence] and [GuardedOperation] implement this interface so that
/// lifecycle owners can manage them uniformly and type-safely.
abstract interface class Disposable {
  /// Whether this resource has been disposed.
  bool get isDisposed;

  /// Releases resources. Implementations must be idempotent.
  void dispose();
}
