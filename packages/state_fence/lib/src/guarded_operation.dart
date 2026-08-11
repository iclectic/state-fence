import 'dart:async';

import 'disposable.dart';
import 'fence_clock.dart';
import 'fence_event.dart';
import 'fence_scheduler.dart';
import 'operation_outcome.dart';
import 'operation_policy.dart';
import 'operation_token.dart';
import 'reporter.dart';
import 'timeline.dart';
import 'violation.dart';

/// Guards an asynchronous operation against stale results, duplicate
/// invocations and timeouts.
///
/// Supports [OperationPolicy.latestWins] and [OperationPolicy.firstWins].
/// Each call to [run] returns an [OperationOutcome] describing whether its
/// result was accepted, ignored or timed out.
///
/// When a [timeout] is configured, the [run] future resolves with an
/// [OperationTimedOut] outcome as soon as the timeout fires. Callers are
/// never left waiting on a stuck operation. If the underlying action
/// completes after the timeout, its result is discarded.
class GuardedOperation<T> implements Disposable {
  /// The name of this operation, used in violations and diagnostics.
  final String name;

  /// The concurrency policy governing overlapping invocations.
  final OperationPolicy policy;

  /// An optional timeout applied to each invocation. Null disables timeouts.
  final Duration? timeout;

  final OperationTokenGenerator _tokenGenerator;
  final StateFenceReporter _reporter;
  final FenceScheduler _scheduler;
  final FenceClock _clock;
  final Timeline? _timeline;

  OperationToken? _latestAccepted;
  OperationToken? _inFlight;
  bool _disposed = false;

  /// Creates a guarded operation.
  ///
  /// [tokenGenerator] controls invocation identity and is injectable for tests.
  /// [reporter] receives timeout and post-dispose violations. [scheduler]
  /// drives timeouts and is injectable for tests. [timeline], when supplied,
  /// records bounded diagnostic events.
  GuardedOperation({
    required this.name,
    required this.policy,
    this.timeout,
    OperationTokenGenerator? tokenGenerator,
    StateFenceReporter? reporter,
    FenceScheduler? scheduler,
    Timeline? timeline,
  })  : _tokenGenerator = tokenGenerator ?? MonotonicTokenGenerator(),
        _reporter = reporter ?? const DevNullReporter(),
        _scheduler = scheduler ?? const RealFenceScheduler(),
        _clock = scheduler != null
            ? FenceSchedulerClock(scheduler)
            : const RealFenceClock(),
        _timeline = timeline;

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
    _timeline?.add(
      OperationStartedEvent(
        source: name,
        timestamp: _clock.now(),
        token: token,
      ),
    );

    switch (policy) {
      case OperationPolicy.latestWins:
        return _runLatestWins(token, action);
      case OperationPolicy.firstWins:
        return _runFirstWins(token, action);
    }
  }

  Future<OperationOutcome<T>> _runLatestWins(
    OperationToken token,
    Future<T> Function() action,
  ) {
    _latestAccepted = token;
    final completer = Completer<OperationOutcome<T>>();
    final timerHandle = _startTimeout(token, completer);
    _invoke(action).then((result) {
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
    final completer = Completer<OperationOutcome<T>>();
    final timerHandle = _startTimeout(token, completer);
    _invoke(action).then((result) {
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
        errorDescription: result.error.toString(),
      ),
    );
    return OperationFailure<T>(token, result.error!, result.stackTrace!);
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
        // Allow a retry: the timed-out invocation no longer blocks new runs.
        _inFlight = null;
      }
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
    _timeline?.add(
      OwnerDisposedEvent(
        source: name,
        timestamp: _clock.now(),
      ),
    );
  }

  void _safeReport(StateFenceViolation violation) {
    try {
      _reporter.report(violation);
    } catch (_) {
      // Reporter failures are isolated so timeline recording is not lost.
    }
  }
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
