/// Produces the diagnostic text stored for a thrown error.
///
/// [GuardedOperation] calls this before it records an
/// [OperationFailedEvent]. [exportTimelineJson] writes the returned text and
/// does not call [Object.toString] on the error.
///
/// The default, [describeErrorRuntimeType], keeps the exception message out
/// of the timeline. Pass [describeErrorMessage], or another function, only
/// when that message is safe to store.
typedef ErrorDescriber = String Function(Object error, StackTrace stackTrace);

/// Records [error]'s runtime type and ignores [stackTrace].
///
/// This is the default [ErrorDescriber]. A secret in the exception message
/// is not recorded, so it cannot appear in [exportTimelineJson].
String describeErrorRuntimeType(Object error, StackTrace stackTrace) =>
    error.runtimeType.toString();

/// Records the result of `toString` on [error] and ignores [stackTrace].
///
/// This opts in to the full message. [exportTimelineJson] will include that
/// text, so use it only when the message is safe to store.
String describeErrorMessage(Object error, StackTrace stackTrace) =>
    error.toString();
