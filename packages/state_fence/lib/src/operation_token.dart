import 'package:meta/meta.dart';

/// A monotonic identifier for a single guarded operation invocation.
///
/// Tokens are produced by an [OperationTokenGenerator] and compared by value.
/// The newest accepted token determines which in-flight result may be applied.
@immutable
final class OperationToken implements Comparable<OperationToken> {
  /// The underlying monotonically increasing value.
  final int value;

  /// Creates a token with the given [value].
  const OperationToken(this.value);

  /// Compares this token to [other] by [value].
  @override
  int compareTo(OperationToken other) => value.compareTo(other.value);

  /// Whether [other] is an [OperationToken] with the same [value].
  @override
  bool operator ==(Object other) =>
      other is OperationToken && other.value == value;

  /// The hash code of [value].
  @override
  int get hashCode => value.hashCode;

  /// A string representation of this token, such as `OperationToken(3)`.
  @override
  String toString() => 'OperationToken($value)';
}

/// Produces unique, monotonic [OperationToken]s for guarded operation runs.
///
/// The default [MonotonicTokenGenerator] is suitable for production use. Tests
/// can supply a deterministic implementation to control invocation identity.
abstract interface class OperationTokenGenerator {
  /// Returns the next unique token.
  OperationToken next();
}

/// A simple [OperationTokenGenerator] that increments an internal counter.
final class MonotonicTokenGenerator implements OperationTokenGenerator {
  int _current;

  /// Creates a generator whose first token will have [start] as its value.
  MonotonicTokenGenerator({int start = 0}) : _current = start;

  @override
  OperationToken next() => OperationToken(_current++);
}
