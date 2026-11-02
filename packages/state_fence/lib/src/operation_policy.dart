/// Concurrency policies for a [GuardedOperation].
///
/// [latestWins] and [firstWins] keep the behaviour they had before the later
/// policies were added. None of these policies cancels a Dart future. A
/// superseded or timed-out action keeps running, and its late result is
/// discarded.
enum OperationPolicy {
  /// Accept only the result of the newest invocation. Older in-flight results
  /// are reported as [OperationIgnoredAsStale] when they settle.
  latestWins,

  /// Ignore new invocations while one is already in flight. The second and
  /// subsequent calls are reported as [OperationIgnoredAsDuplicate] until the
  /// first one completes.
  firstWins,

  /// Like [latestWins], but the previous invocation's future completes as
  /// [OperationIgnoredAsStale] as soon as a newer run starts.
  ///
  /// The previous action is not cancelled. Its late result is discarded.
  restartable,

  /// Run invocations one at a time, in the order they were started.
  ///
  /// A later call waits until the earlier one has been accepted, has failed
  /// or has timed out. Queued calls are not treated as duplicates.
  sequential,

  /// Accept every invocation, including ones that overlap.
  ///
  /// Nothing is discarded as stale or as a duplicate. Each call still obeys
  /// its own timeout.
  parallel,
}
