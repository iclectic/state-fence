/// Concurrency policies for a [GuardedOperation].
///
/// Only [latestWins] and [firstWins] are supported in the MVP. Other policies
/// are reserved for future versions and must not be passed to a
/// [GuardedOperation] yet.
enum OperationPolicy {
  /// Accept only the result of the newest invocation. Older in-flight results
  /// are reported as [OperationIgnoredAsStale].
  latestWins,

  /// Ignore new invocations while one is already in flight. The second and
  /// subsequent calls are reported as [OperationIgnoredAsDuplicate] until the
  /// first one completes.
  firstWins,
}
