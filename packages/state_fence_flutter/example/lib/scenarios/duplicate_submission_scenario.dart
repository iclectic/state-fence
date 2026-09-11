import 'dart:async';

import 'package:flutter/material.dart';
import 'package:state_fence/state_fence.dart';
import 'package:state_fence_flutter/state_fence_flutter.dart';

import '../diagnostics.dart';
import '../widgets/diagnostics_panel.dart';
import '../widgets/scenario_page.dart';
import '../widgets/status_pill.dart';

/// Demonstrates a duplicate submission when a payment is triggered twice.
///
/// Without StateFence, both taps fire separate payment requests. With
/// [GuardedOperation] using [OperationPolicy.firstWins], the second request is
/// ignored as a duplicate while the first is in flight.
class DuplicateSubmissionScenario extends StatefulWidget {
  /// Creates the duplicate submission scenario screen.
  const DuplicateSubmissionScenario({super.key});

  @override
  State<DuplicateSubmissionScenario> createState() =>
      _DuplicateSubmissionScenarioState();
}

class _Attempt {
  _Attempt(this.label, this.tone, this.icon);

  final String label;
  final StatusTone tone;
  final IconData icon;
}

const Color _accent = Color(0xFF10B981);

class _DuplicateSubmissionScenarioState
    extends State<DuplicateSubmissionScenario> with StateFenceStateMixin {
  late final SharedDiagnostics _diag = SharedDiagnostics();
  late final GuardedOperation<String> _pay = fenceOwner.register(
    GuardedOperation<String>(
      name: 'pay',
      policy: OperationPolicy.firstWins,
      reporter: _diag.reporter,
      timeline: _diag.timeline,
    ),
  );

  final List<_Attempt> _attempts = <_Attempt>[];
  bool _busy = false;
  int _charges = 0;

  Future<String> _charge() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    _charges++;
    return 'Payment succeeded (charge #$_charges)';
  }

  _Attempt _outcomeToAttempt(String label, OperationOutcome<String> outcome) {
    return switch (outcome) {
      OperationSuccess(:final value) =>
        _Attempt('$label: $value', StatusTone.success, Icons.check_rounded),
      OperationIgnoredAsDuplicate() => _Attempt(
          '$label: ignored as duplicate',
          StatusTone.warning,
          Icons.block_rounded,
        ),
      OperationFailure() =>
        _Attempt('$label: failed', StatusTone.error, Icons.error_outline),
      _ => _Attempt('$label: $outcome', StatusTone.neutral, Icons.info_outline),
    };
  }

  Future<void> _doubleTap() async {
    setState(() {
      _busy = true;
      _attempts.clear();
    });

    // Fire two charges at the same instant, exactly as a double tap would.
    final Future<OperationOutcome<String>> first = _pay.run(_charge);
    final Future<OperationOutcome<String>> second = _pay.run(_charge);
    final List<OperationOutcome<String>> outcomes =
        await Future.wait(<Future<OperationOutcome<String>>>[first, second]);

    if (!mounted) return;
    setState(() {
      _attempts
        ..add(_outcomeToAttempt('First tap', outcomes[0]))
        ..add(_outcomeToAttempt('Second tap', outcomes[1]));
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return ScenarioPage(
      title: 'Duplicate Submission',
      icon: Icons.payments_outlined,
      accent: _accent,
      problem:
          'An impatient user taps "Pay" twice. Two payment requests fire and '
          'the customer is charged twice.',
      solution:
          'firstWins accepts the first request and ignores the second while '
          'the first is still in flight, so only one charge happens.',
      children: [
        FilledButton.icon(
          onPressed: _busy ? null : _doubleTap,
          icon: _busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.touch_app_outlined),
          label: Text(_busy ? 'Processing...' : 'Double tap "Pay"'),
        ),
        const SizedBox(height: 8),
        Text(
          'Fires two payment requests at the same time.',
          style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        if (_attempts.isNotEmpty) ...[
          const SizedBox(height: 20),
          ..._attempts.map(
            (a) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(child: Text(a.label, style: text.bodyMedium)),
                  StatusPill(label: a.tone.name, tone: a.tone, icon: a.icon),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.receipt_long_outlined,
                  size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                'Total charges made: $_charges',
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        DiagnosticsPanel(
          violations: _diag.reporter.violations,
          eventCount: _diag.timeline.length,
        ),
      ],
    );
  }
}
