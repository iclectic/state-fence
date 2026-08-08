import 'dart:async';

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
/// The MVP supports [OperationPolicy.latestWins] and
/// [OperationPolicy.firstWins]. A [GuardedOperation] is single-use across
/// calls: each call to [run] returns an [OperationOutcome] describing whether
/// its result was accepted, ignored or timed out.
class GuardedOperation<T> {
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
  bool get isDisposed => _disposed;

  /// Runs [action] under this operation's policy.
  ///
  /// The returned future resolves once the invocation has completed, been
  /// ignored or timed out. The outcome's [OperationOutcome.token] identifies
  /// the invocation regardless of which branch was taken.
  Future<OperationOutcome<T>> run(Future<T> Function() action) async {
    if (_disposed) {
      return _disposedOutcome();
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
  ) async {
    _latestAccepted = token;
    final timerHandle = _startTimeout(token);
    try {
      final value = await action();
      timerHandle?.cancel();
      if (_disposed) return _disposedOutcome(token: token);
      if (_latestAccepted != token) {
        _recordStale(token, _latestAccepted!);
        return OperationIgnoredAsStale<T>(token, _latestAccepted!);
      }
      _recordSuccess(token);
      return OperationSuccess<T>(token, value);
    } catch (error, stackTrace) {
      timerHandle?.cancel();
      if (_disposed) return _disposedOutcome(token: token);
      if (_latestAccepted != token) {
        _recordStale(token, _latestAccepted!);
        return OperationIgnoredAsStale<T>(token, _latestAccepted!);
      }
      _recordFailure(token, error);
      return OperationFailure<T>(token, error, stackTrace);
    }
  }

  Future<OperationOutcome<T>> _runFirstWins(
    OperationToken token,
    Future<T> Function() action,
  ) async {
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
      return OperationIgnoredAsDuplicate<T>(token, existing);
    }
    _inFlight = token;
    final timerHandle = _startTimeout(token);
    try {
      final value = await action();
      timerHandle?.cancel();
      if (_disposed) return _disposedOutcome(token: token);
      if (_inFlight != token) {
        // Should not happen under firstWins, but guard against reentrancy.
        _recordStale(token, _inFlight ?? token);
        return OperationIgnoredAsStale<T>(token, _inFlight ?? token);
      }
      _inFlight = null;
      _recordSuccess(token);
      return OperationSuccess<T>(token, value);
    } catch (error, stackTrace) {
      timerHandle?.cancel();
      if (_disposed) return _disposedOutcome(token: token);
      if (_inFlight != token) {
        _recordStale(token, _inFlight ?? token);
        return OperationIgnoredAsStale<T>(token, _inFlight ?? token);
      }
      _inFlight = null;
      _recordFailure(token, error);
      return OperationFailure<T>(token, error, stackTrace);
    }
  }

  void _recordSuccess(OperationToken token) {
    _timeline?.add(
      OperationSucceededEvent(
        source: name,
        timestamp: _clock.now(),
        token: token,
      ),
    );
  }

  void _recordFailure(OperationToken token, Object error) {
    _timeline?.add(
      OperationFailedEvent(
        source: name,
        timestamp: _clock.now(),
        token: token,
        errorDescription: error.toString(),
      ),
    );
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

  FenceTimerHandle? _startTimeout(OperationToken token) {
    final duration = timeout;
    if (duration == null) return null;
    return _scheduler.timer(duration, () {
      if (_disposed) return;
      final current = _latestAccepted;
      final inFlight = _inFlight;
      final stillActive = (current != null && current == token) ||
          (inFlight != null && inFlight == token);
      if (!stillActive) return;
      _timeline?.add(
        OperationTimedOutEvent(
          source: name,
          timestamp: _clock.now(),
          token: token,
        ),
      );
      _safeReport(
        StateFenceViolation(
          fenceName: name,
          previousState: OperationPolicy,
          attemptedState: OperationPolicy,
          timestamp: _clock.now(),
          operation: name,
          reason: 'Operation "$name" timed out after $duration.',
        ),
      );
    });
  }

  OperationOutcome<T> _disposedOutcome({OperationToken? token}) {
    final effectiveToken = token ?? _tokenGenerator.next();
    final now = _clock.now();
    _timeline?.add(
      OwnerDisposedEvent(
        source: name,
        timestamp: now,
        operation: name,
      ),
    );
    _safeReport(
      StateFenceViolation(
        fenceName: name,
        previousState: OperationPolicy,
        attemptedState: OperationPolicy,
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
  /// disposed state and report a violation through [reporter].
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
