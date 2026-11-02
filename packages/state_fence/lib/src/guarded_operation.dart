import 'dart:async';

import 'disposable.dart';
import 'error_describer.dart';
import 'fence_clock.dart';
import 'fence_event.dart';
import 'fence_scheduler.dart';
import 'operation_outcome.dart';
import 'operation_policy.dart';
import 'operation_token.dart';
import 'reporter.dart';
import 'retry_policy.dart';
import 'timeline.dart';
import 'violation.dart';

/// Guards an asynchronous operation against stale results, duplicate
/// invocations and timeouts.
///
/// Supports [OperationPolicy.latestWins], [OperationPolicy.firstWins],
/// [OperationPolicy.restartable], [OperationPolicy.sequential] and
/// [OperationPolicy.parallel]. Each call to [run] returns an
/// [OperationOutcome] describing whether its result was accepted, ignored
/// or timed out.
///
/// When a [timeout] is configured, the [run] future resolves with an
/// [OperationTimedOut] outcome as soon as the timeout fires. Callers are
/// never left waiting on a stuck operation. If the underlying action
/// completes after the timeout, its result is discarded.
///
/// [retry], when set, reruns the action after a failure. It does not retry
/// timeouts, stale results or duplicates, and it does not turn the operation
/// into a data client.
///
/// A failure recorded on the timeline uses [errorDescriber]. The default,
/// [describeErrorRuntimeType], stores only the error's runtime type. The
/// [OperationFailure] returned to the caller still carries the error object.
/// [exportTimelineJson] writes the describer's text and does not call
/// [Object.toString] on the thrown error.
class GuardedOperation<T> implements Disposable {
  /// The name of this operation, used in violations and diagnostics.
  final String name;

  /// The concurrency policy governing overlapping invocations.
  final OperationPolicy policy;

  /// An optional timeout applied to each invocation. Null disables timeouts.
  final Duration? timeout;

  /// Optional reruns after a thrown failure. Null disables retries.
  final RetryPolicy? retry;

  final OperationTokenGenerator _tokenGenerator;
  final StateFenceReporter _reporter;
  final FenceScheduler _scheduler;
  final FenceClock _clock;
  final Timeline? _timeline;
  final ErrorDescriber _describeError;

  OperationToken? _latestAccepted;
  OperationToken? _inFlight;
  _RestartableRun<T>? _restartable;
  final List<_QueuedRun<T>> _queue = [];
  OperationToken? _sequentialActive;
  bool _disposed = false;

  /// Creates a guarded operation.
  ///
  /// [tokenGenerator] controls invocation identity and is injectable for tests.
  /// [reporter] receives timeout and post-dispose violations. [scheduler]
  /// drives timeouts and retry delays, and is injectable for tests. [clock]
  /// controls timestamps;
  /// when omitted it follows [scheduler] if one was supplied, so a fake
  /// scheduler yields consistent timestamps without extra wiring. [timeline],
  /// when supplied, records bounded diagnostic events. [errorDescriber]
  /// turns a thrown error into the text stored on the timeline. It defaults
  /// to [describeErrorRuntimeType], which omits the exception message. Pass
  /// [describeErrorMessage] to opt in to the full message.
  GuardedOperation({
    required this.name,
    required this.policy,
    this.timeout,
    this.retry,
    OperationTokenGenerator? tokenGenerator,
    StateFenceReporter? reporter,
    FenceScheduler? scheduler,
    FenceClock? clock,
    Timeline? timeline,
    ErrorDescriber? errorDescriber,
  })  : _tokenGenerator = tokenGenerator ?? MonotonicTokenGenerator(),
        _reporter = reporter ?? const DevNullReporter(),
        _scheduler = scheduler ?? const RealFenceScheduler(),
        _clock = clock ??
            (scheduler != null
                ? FenceSchedulerClock(scheduler)
                : const RealFenceClock()),
        _timeline = timeline,
        _describeError = errorDescriber ?? describeErrorRuntimeType;

  /// Whether this operation has been disposed.
  @override
  bool get isDisposed => _disposed;

  /// Runs [action] under this operation's policy.
  ///
  /// The returned future resolves once the invocation has completed, been
  /// ignored or timed out. The outcome's [OperationOutcome.token] identifies
  /// the invocation regardless of which branch was taken.
  Future<OperationOutcome<T>> run(Future<T> Function() action) {
    if (_disposed) {
      return Future.value(_disposedOutcome());
    }

    final token = _tokenGenerator.next();
    switch (policy) {
      case OperationPolicy.sequential:
        return _enqueueSequential(token, action);
      case OperationPolicy.latestWins:
        _recordStarted(token);
        return _runLatestWins(token, action);
      case OperationPolicy.firstWins:
        return _runFirstWins(token, action);
      case OperationPolicy.restartable:
        _recordStarted(token);
        return _runRestartable(token, action);
      case OperationPolicy.parallel:
        _recordStarted(token);
        return _runParallel(token, action);
    }
  }

  Future<OperationOutcome<T>> _runLatestWins(
    OperationToken token,
    Future<T> Function() action,
  ) {
    _latestAccepted = token;
    final completer = Completer<OperationOutcome<T>>();
    final timerHandle = _startTimeout(token, completer);
    _invokeWithRetry(token, action, () => completer.isCompleted).then((result) {
      timerHandle?.cancel();
      if (completer.isCompleted) return;
      if (_disposed) {
        completer.complete(_disposedOutcome(token: token));
        return;
      }
      final latest = _latestAccepted;
      if (latest != null && latest != token) {
        _recordStale(token, latest);
        completer.complete(OperationIgnoredAsStale<T>(token, latest));
        return;
      }
      completer.complete(_settle(token, result));
    });
    return completer.future;
  }

  Future<OperationOutcome<T>> _runRestartable(
    OperationToken token,
    Future<T> Function() action,
  ) {
    final previous = _restartable;
    if (previous != null && !previous.completer.isCompleted) {
      previous.timer?.cancel();
      _recordStale(previous.token, token);
      previous.completer.complete(
        OperationIgnoredAsStale<T>(previous.token, token),
      );
    }
    _latestAccepted = token;
    final completer = Completer<OperationOutcome<T>>();
    final current = _RestartableRun<T>(token, completer);
    _restartable = current;
    current.timer = _startTimeout(token, completer);
    _invokeWithRetry(token, action, () => completer.isCompleted).then((result) {
      current.timer?.cancel();
      if (completer.isCompleted) return;
      if (_disposed) {
        completer.complete(_disposedOutcome(token: token));
        return;
      }
      if (_restartable?.token != token) {
        final latest = _restartable?.token ?? token;
        _recordStale(token, latest);
        completer.complete(OperationIgnoredAsStale<T>(token, latest));
        return;
      }
      completer.complete(_settle(token, result));
    });
    return completer.future;
  }

  Future<OperationOutcome<T>> _enqueueSequential(
    OperationToken token,
    Future<T> Function() action,
  ) {
    final completer = Completer<OperationOutcome<T>>();
    _queue.add(_QueuedRun<T>(token, action, completer));
    _drainSequential();
    return completer.future;
  }

  void _drainSequential() {
    if (_disposed || _sequentialActive != null || _queue.isEmpty) return;
    final item = _queue.removeAt(0);
    _sequentialActive = item.token;
    _recordStarted(item.token);
    item.timer = _startTimeout(item.token, item.completer);
    _invokeWithRetry(item.token, item.action, () => item.completer.isCompleted)
        .then((result) {
      item.timer?.cancel();
      if (item.completer.isCompleted) {
        _endSequential(item.token);
        return;
      }
      if (_disposed) {
        item.completer.complete(_disposedOutcome(token: item.token));
        _endSequential(item.token);
        return;
      }
      item.completer.complete(_settle(item.token, result));
      _endSequential(item.token);
    });
  }

  void _endSequential(OperationToken token) {
    if (_sequentialActive != token) return;
    _sequentialActive = null;
    _drainSequential();
  }

  Future<OperationOutcome<T>> _runParallel(
    OperationToken token,
    Future<T> Function() action,
  ) {
    final completer = Completer<OperationOutcome<T>>();
    final timerHandle = _startTimeout(token, completer);
    _invokeWithRetry(token, action, () => completer.isCompleted).then((result) {
      timerHandle?.cancel();
      if (completer.isCompleted) return;
      if (_disposed) {
        completer.complete(_disposedOutcome(token: token));
        return;
      }
      completer.complete(_settle(token, result));
    });
    return completer.future;
  }

  Future<OperationOutcome<T>> _runFirstWins(
    OperationToken token,
    Future<T> Function() action,
  ) {
    final existing = _inFlight;
    if (existing != null) {
      _timeline?.add(
        OperationIgnoredAsDuplicateEvent(
          source: name,
          timestamp: _clock.now(),
          token: token,
          blockedBy: existing,
        ),
      );
      return Future.value(OperationIgnoredAsDuplicate<T>(token, existing));
    }
    _inFlight = token;
    _recordStarted(token);
    final completer = Completer<OperationOutcome<T>>();
    final timerHandle = _startTimeout(token, completer);
    _invokeWithRetry(token, action, () => completer.isCompleted).then((result) {
      timerHandle?.cancel();
      if (completer.isCompleted) return;
      if (_inFlight == token) _inFlight = null;
      if (_disposed) {
        completer.complete(_disposedOutcome(token: token));
        return;
      }
      completer.complete(_settle(token, result));
    });
    return completer.future;
  }

  Future<_ActionResult<T>> _invokeWithRetry(
    OperationToken token,
    Future<T> Function() action,
    bool Function() abandoned,
  ) async {
    final policy = retry;
    var attempts = 0;
    while (true) {
      if (abandoned() || _disposed) {
        return _ActionResult<T>.failure(
          StateError('Operation "$name" was abandoned.'),
          StackTrace.current,
        );
      }
      attempts++;
      final result = await _invoke(action);
      if (abandoned() || _disposed || result.isSuccess) return result;
      final canRetry = policy != null && attempts < policy.maxAttempts;
      if (!canRetry) return result;
      _timeline?.add(
        OperationFailedEvent(
          source: name,
          timestamp: _clock.now(),
          token: token,
          errorDescription: _descriptionOf(result),
        ),
      );
      await _pause(policy.delayAfter(attempts));
    }
  }

  Future<void> _pause(Duration duration) {
    final completer = Completer<void>();
    _scheduler.timer(duration, () {
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  void _recordStarted(OperationToken token) {
    _timeline?.add(
      OperationStartedEvent(
        source: name,
        timestamp: _clock.now(),
        token: token,
      ),
    );
  }

  /// Runs [action], capturing synchronous and asynchronous errors uniformly.
  Future<_ActionResult<T>> _invoke(Future<T> Function() action) async {
    try {
      final value = await action();
      return _ActionResult<T>.success(value);
    } catch (error, stackTrace) {
      return _ActionResult<T>.failure(error, stackTrace);
    }
  }

  /// Converts a settled action result into an accepted outcome, recording
  /// the corresponding timeline event.
  OperationOutcome<T> _settle(OperationToken token, _ActionResult<T> result) {
    if (result.isSuccess) {
      _timeline?.add(
        OperationSucceededEvent(
          source: name,
          timestamp: _clock.now(),
          token: token,
        ),
      );
      return OperationSuccess<T>(token, result.value as T);
    }
    _timeline?.add(
      OperationFailedEvent(
        source: name,
        timestamp: _clock.now(),
        token: token,
        errorDescription: _descriptionOf(result),
      ),
    );
    return OperationFailure<T>(token, result.error!, result.stackTrace!);
  }

  String _descriptionOf(_ActionResult<T> result) {
    final Object error = result.error!;
    final StackTrace stackTrace = result.stackTrace!;
    return _describeError(error, stackTrace);
  }

  void _recordStale(OperationToken token, OperationToken supersededBy) {
    _timeline?.add(
      OperationIgnoredAsStaleEvent(
        source: name,
        timestamp: _clock.now(),
        token: token,
        supersededBy: supersededBy,
      ),
    );
  }

  FenceTimerHandle? _startTimeout(
    OperationToken token,
    Completer<OperationOutcome<T>> completer,
  ) {
    final duration = timeout;
    if (duration == null) return null;
    return _scheduler.timer(duration, () {
      if (_disposed || completer.isCompleted) return;
      _timeline?.add(
        OperationTimedOutEvent(
          source: name,
          timestamp: _clock.now(),
          token: token,
        ),
      );
      if (policy == OperationPolicy.firstWins && _inFlight == token) {
        // The timed-out invocation no longer blocks a new run.
        _inFlight = null;
      }
      if (policy == OperationPolicy.restartable &&
          _restartable?.token == token) {
        _restartable = null;
      }
      _endSequential(token);
      // Complete the outcome before reporting so a throwing reporter can
      // never leave the run future unresolved.
      completer.complete(OperationTimedOut<T>(token, duration));
      _safeReport(
        OperationTimeoutViolation(
          source: name,
          timestamp: _clock.now(),
          operation: name,
          token: token,
          timeout: duration,
          reason: 'Operation "$name" timed out after $duration.',
        ),
      );
    });
  }

  OperationOutcome<T> _disposedOutcome({OperationToken? token}) {
    final effectiveToken = token ?? const OperationToken(-1);
    final now = _clock.now();
    _safeReport(
      UseAfterDisposeViolation(
        source: name,
        timestamp: now,
        operation: name,
        reason: 'Operation "$name" was used after dispose.',
      ),
    );
    return OperationFailure<T>(
      effectiveToken,
      StateError('GuardedOperation "$name" has been disposed.'),
      StackTrace.current,
    );
  }

  /// Releases resources held by this operation.
  ///
  /// Subsequent calls to [run] return an [OperationFailure] describing the
  /// disposed state and report a [UseAfterDisposeViolation] through the
  /// reporter. In-flight invocations resolve with the same failure when
  /// their action settles.
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _latestAccepted = null;
    _inFlight = null;
    final queued = List<_QueuedRun<T>>.of(_queue);
    _queue.clear();
    for (final item in queued) {
      item.timer?.cancel();
      if (!item.completer.isCompleted) {
        item.completer.complete(_disposedOutcome(token: item.token));
      }
    }
    _sequentialActive = null;
    final restartable = _restartable;
    _restartable = null;
    if (restartable != null && !restartable.completer.isCompleted) {
      restartable.timer?.cancel();
      restartable.completer.complete(
        _disposedOutcome(token: restartable.token),
      );
    }
    _timeline?.add(OwnerDisposedEvent(source: name, timestamp: _clock.now()));
  }

  void _safeReport(StateFenceViolation violation) {
    try {
      _reporter.report(violation);
    } catch (_) {
      // Reporter failures are isolated so timeline recording is not lost.
    }
  }
}

class _RestartableRun<T> {
  _RestartableRun(this.token, this.completer);

  final OperationToken token;
  final Completer<OperationOutcome<T>> completer;
  FenceTimerHandle? timer;
}

class _QueuedRun<T> {
  _QueuedRun(this.token, this.action, this.completer);

  final OperationToken token;
  final Future<T> Function() action;
  final Completer<OperationOutcome<T>> completer;
  FenceTimerHandle? timer;
}

/// The settled result of an action: either a value or an error.
final class _ActionResult<T> {
  final T? value;
  final Object? error;
  final StackTrace? stackTrace;
  final bool isSuccess;

  _ActionResult.success(this.value)
      : error = null,
        stackTrace = null,
        isSuccess = true;

  _ActionResult.failure(this.error, this.stackTrace)
      : value = null,
        isSuccess = false;
}
