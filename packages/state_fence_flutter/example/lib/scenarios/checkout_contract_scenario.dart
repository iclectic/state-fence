import 'dart:async';

import 'package:flutter/material.dart';
import 'package:state_fence/state_fence.dart';
import 'package:state_fence_flutter/state_fence_flutter.dart';

import '../diagnostics.dart';
import '../widgets/diagnostics_panel.dart';
import '../widgets/scenario_page.dart';
import '../widgets/status_pill.dart';

/// Checkout states for the combined fence and operation demo.
///
/// The widget keeps its own copy and assigns it only when the fence accepts
/// a transition.
sealed class CheckoutState {
  const CheckoutState();
}

/// No payment is in flight.
final class Idle extends CheckoutState {
  const Idle();
}

/// A payment has been accepted and is in flight.
final class Submitting extends CheckoutState {
  const Submitting();
}

/// The payment was accepted and produced a [receipt].
final class Paid extends CheckoutState {
  const Paid(this.receipt);

  /// Receipt text returned by the accepted operation.
  final String receipt;
}

/// The payment failed or timed out.
final class Failed extends CheckoutState {
  const Failed(this.message);

  /// Why the payment did not complete.
  final String message;
}

/// One screen that runs a fence and a guarded operation together.
///
/// The flow rejects an illegal jump, reports a stuck submitting state, then
/// applies failure, timeout and success through the fence. Duplicate and
/// stale outcomes leave the displayed state unchanged.
class CheckoutContractScenario extends StatefulWidget {
  /// Creates the checkout contract screen.
  const CheckoutContractScenario({super.key});

  @override
  State<CheckoutContractScenario> createState() =>
      _CheckoutContractScenarioState();
}

const Color _accent = Color(0xFF7C3AED);
const Duration _stuckLimit = Duration(milliseconds: 800);
const Duration _failureDelay = Duration(milliseconds: 200);
const Duration _operationTimeout = Duration(milliseconds: 400);
const Duration _slowQuote = Duration(milliseconds: 350);
const Duration _fastQuote = Duration(milliseconds: 80);

class _CheckoutContractScenarioState extends State<CheckoutContractScenario>
    with StateFenceStateMixin {
  late final SharedDiagnostics _diag = SharedDiagnostics();
  late final _FanOutReporter _reporter = _FanOutReporter(
    collecting: _diag.reporter,
    onReported: _refresh,
  );
  late final StateFence<CheckoutState> _fence = fenceOwner.register(
    StateFence<CheckoutState>(
      name: 'checkout',
      initialState: const Idle(),
      rules: [
        allow<Idle, Submitting>(),
        allow<Submitting, Paid>(),
        allow<Submitting, Failed>(),
        allow<Failed, Submitting>(),
      ],
      reporter: _reporter,
      timeline: _diag.timeline,
      stuckStateTimeouts: const {Submitting: _stuckLimit},
    ),
  );
  late final GuardedOperation<String> _pay = fenceOwner.register(
    GuardedOperation<String>(
      name: 'pay',
      policy: OperationPolicy.firstWins,
      timeout: _operationTimeout,
      reporter: _reporter,
      timeline: _diag.timeline,
    ),
  );
  late final GuardedOperation<String> _quote = fenceOwner.register(
    GuardedOperation<String>(
      name: 'quote',
      policy: OperationPolicy.latestWins,
      reporter: _reporter,
      timeline: _diag.timeline,
    ),
  );

  CheckoutState _ui = const Idle();
  final List<String> _log = <String>[];
  bool _running = false;
  bool _finished = false;

  void _refresh() {
    if (!mounted) return;
    setState(() {});
  }

  void _logLine(String message) {
    if (!mounted) return;
    setState(() => _log.add(message));
  }

  /// Assigns [_ui] only when [result] is [TransitionAccepted].
  void _take(TransitionResult<CheckoutState> result) {
    if (!mounted) return;
    switch (result) {
      case TransitionAccepted(:final state):
        setState(() {
          _ui = state;
          _log.add('Accepted. UI is now ${_describe(state)}.');
        });
      case TransitionRejected(:final violation):
        setState(() {
          _log.add('Rejected: ${violation.reason}');
          _log.add('UI unchanged: ${_describe(_ui)}.');
        });
    }
  }

  void _applyOutcome(OperationOutcome<String> outcome) {
    switch (outcome) {
      case OperationSuccess(:final value):
        _take(
          _fence.transition(
            Paid(value),
            operation: 'pay',
            metadata: const <String, Object?>{
              'token': 'card-token-secret',
              'amount': '42.00',
            },
          ),
        );
      case OperationFailure(:final error):
        _take(_fence.transition(Failed('$error'), operation: 'pay'));
      case OperationTimedOut(:final timeout):
        _logLine('Timed out after $timeout. The future is not cancelled.');
        _take(
          _fence.transition(
            Failed('Timed out after $timeout.'),
            operation: 'pay',
          ),
        );
      case OperationIgnoredAsStale():
        _logLine('Ignored as stale. UI stays ${_describe(_ui)}.');
      case OperationIgnoredAsDuplicate():
        _logLine('Ignored as duplicate. UI stays ${_describe(_ui)}.');
    }
  }

  Future<void> _runFlow() async {
    _take(_fence.transition(const Paid('skipped'), operation: 'pay'));

    _take(_fence.transition(const Submitting(), operation: 'pay'));
    await Future<void>.delayed(_stuckLimit + const Duration(milliseconds: 150));
    if (!mounted) return;
    final bool stuck =
        _diag.reporter.violations.whereType<StuckStateViolation>().isNotEmpty;
    _logLine(
      stuck
          ? 'Stuck-state violation reported. UI stays ${_describe(_ui)}.'
          : 'Stuck-state violation was not reported.',
    );

    final Future<OperationOutcome<String>> failing = _pay.run(() async {
      await Future<void>.delayed(_failureDelay);
      throw StateError('card declined');
    });
    final OperationOutcome<String> duplicate = await _pay.run(
      () async => 'second tap',
    );
    if (!mounted) return;
    _applyOutcome(duplicate);
    final OperationOutcome<String> failure = await failing;
    if (!mounted) return;
    _applyOutcome(failure);

    _take(_fence.transition(const Submitting(), operation: 'pay'));
    final OperationOutcome<String> timedOut = await _pay.run(
      () => Completer<String>().future,
    );
    if (!mounted) return;
    _applyOutcome(timedOut);

    _take(_fence.transition(const Submitting(), operation: 'pay'));
    final Future<OperationOutcome<String>> slow = _quote.run(() async {
      await Future<void>.delayed(_slowQuote);
      return 'slow-receipt';
    });
    final Future<OperationOutcome<String>> fast = _quote.run(() async {
      await Future<void>.delayed(_fastQuote);
      return 'fast-receipt';
    });
    final OperationOutcome<String> fastOutcome = await fast;
    if (!mounted) return;
    _applyOutcome(fastOutcome);
    final OperationOutcome<String> slowOutcome = await slow;
    if (!mounted) return;
    _applyOutcome(slowOutcome);
  }

  Future<void> _start() async {
    setState(() {
      _running = true;
      _log.clear();
    });
    try {
      await _runFlow();
      if (!mounted) return;
      setState(() => _finished = true);
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String exported = exportTimelineJson(_diag.timeline);
    final bool redacted = exported.contains('<redacted>');

    return ScenarioPage(
      title: 'Checkout',
      icon: Icons.rule,
      accent: _accent,
      problem: 'A checkout can jump straight to paid, apply a second tap, or '
          'let a slow result overwrite a newer receipt. A submitting screen '
          'can also sit there with no timeout.',
      solution: 'The fence accepts only declared transitions. Success, '
          'failure and timeout are applied through the fence. Stale and '
          'duplicate outcomes leave the displayed state unchanged. The '
          'state label changes only when a transition is accepted.',
      children: [
        FilledButton.icon(
          onPressed: _running || _finished ? null : _start,
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(
            _running
                ? 'Running the combined flow...'
                : _finished
                    ? 'Flow complete'
                    : 'Run the combined flow',
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Current state',
          style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        StatusPill(
          label: _describe(_ui),
          tone: switch (_ui) {
            Idle() => StatusTone.neutral,
            Submitting() => StatusTone.progress,
            Paid() => StatusTone.success,
            Failed() => StatusTone.error,
          },
          icon: switch (_ui) {
            Idle() => Icons.circle_outlined,
            Submitting() => Icons.autorenew_rounded,
            Paid() => Icons.check_rounded,
            Failed() => Icons.error_outline,
          },
        ),
        const SizedBox(height: 8),
        Text(
            switch (_ui) {
              Idle() => 'Waiting to submit.',
              Submitting() => 'Payment in flight.',
              Paid(:final String receipt) => 'Receipt: $receipt',
              Failed(:final String message) => message,
            },
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
        if (_log.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'What happened',
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ..._log.map(
            (String line) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(line, style: text.bodyMedium),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          redacted
              ? 'Token metadata is redacted in the timeline export.'
              : 'The timeline export redacts token once a payment is accepted.',
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(
            'Redacted timeline JSON',
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(
                exported,
                style: text.bodySmall?.copyWith(fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DiagnosticsPanel(
          violations: _diag.reporter.violations,
          eventCount: _diag.timeline.length,
        ),
      ],
    );
  }
}

String _describe(CheckoutState state) => switch (state) {
      Idle() => 'Idle',
      Submitting() => 'Submitting',
      Paid(:final String receipt) => 'Paid($receipt)',
      Failed(:final String message) => 'Failed($message)',
    };

/// Sends each violation to the on-screen collector and to Flutter.
class _FanOutReporter implements StateFenceReporter {
  _FanOutReporter({required this.collecting, required this.onReported});

  final CollectingReporter collecting;
  final VoidCallback onReported;
  final FlutterErrorReporter flutterReporter = const FlutterErrorReporter();

  @override
  void report(StateFenceViolation violation) {
    collecting.report(violation);
    flutterReporter.report(violation);
    onReported();
  }
}
