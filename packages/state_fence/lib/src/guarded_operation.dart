import 'dart:async';

import 'fence_scheduler.dart';
import 'operation_outcome.dart';
import 'operation_policy.dart';
import 'operation_token.dart';
import 'reporter.dart';
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

  OperationToken? _latestAccepted;
  OperationToken? _inFlight;
  bool _disposed = false;

  /// Creates a guarded operation.
  ///
  /// [tokenGenerator] controls invocation identity and is injectable for tests.
  /// [reporter] receives timeout and post-dispose violations. [scheduler]
  /// drives timeouts and is injectable for tests.
  GuardedOperation({
    required this.name,
    required this.policy,
    this.timeout,
    OperationTokenGenerator? tokenGenerator,
    StateFenceReporter? reporter,
    FenceScheduler? scheduler,
  })  : _tokenGenerator = tokenGenerator ?? MonotonicTokenGenerator(),
        _reporter = reporter ?? const DevNullReporter(),
        _scheduler = scheduler ?? const RealFenceScheduler();

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
        return OperationIgnoredAsStale<T>(token, _latestAccepted!);
      }
      return OperationSuccess<T>(token, value);
    } catch (error, stackTrace) {
      timerHandle?.cancel();
      if (_disposed) return _disposedOutcome(token: token);
      if (_latestAccepted != token) {
        return OperationIgnoredAsStale<T>(token, _latestAccepted!);
      }
      return OperationFailure<T>(token, error, stackTrace);
    }
  }

  Future<OperationOutcome<T>> _runFirstWins(
    OperationToken token,
    Future<T> Function() action,
  ) async {
    final existing = _inFlight;
    if (existing != null) {
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
        return OperationIgnoredAsStale<T>(token, _inFlight ?? token);
      }
      _inFlight = null;
      return OperationSuccess<T>(token, value);
    } catch (error, stackTrace) {
      timerHandle?.cancel();
      if (_disposed) return _disposedOutcome(token: token);
      if (_inFlight != token) {
        return OperationIgnoredAsStale<T>(token, _inFlight ?? token);
      }
      _inFlight = null;
      return OperationFailure<T>(token, error, stackTrace);
    }
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
      _reporter.report(
        StateFenceViolation(
          fenceName: name,
          previousState: OperationPolicy,
          attemptedState: OperationPolicy,
          timestamp: _scheduler.now(),
          operation: name,
          reason: 'Operation "$name" timed out after $duration.',
        ),
      );
    });
  }

  OperationOutcome<T> _disposedOutcome({OperationToken? token}) {
    final effectiveToken = token ?? _tokenGenerator.next();
    _reporter.report(
      StateFenceViolation(
        fenceName: name,
        previousState: OperationPolicy,
        attemptedState: OperationPolicy,
        timestamp: _scheduler.now(),
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
  }
}
