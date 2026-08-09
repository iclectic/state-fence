import 'dart:async';

import 'package:flutter/material.dart';
import 'package:state_fence/state_fence.dart';
import 'package:state_fence_flutter/state_fence_flutter.dart';

import '../main.dart';
import '../widgets/violations_panel.dart';

/// Demonstrates a duplicate submission when a button is tapped twice.
///
/// Without StateFence, both taps fire separate payment requests. With
/// [GuardedOperation] using [OperationPolicy.firstWins], the second tap is
/// ignored as a duplicate while the first is in flight.
class DuplicateSubmissionScenario extends StatefulWidget {
  const DuplicateSubmissionScenario({super.key});

  @override
  State<DuplicateSubmissionScenario> createState() =>
      _DuplicateSubmissionScenarioState();
}

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

  String _statusText = 'Ready to pay.';
  bool _isSubmitting = false;

  Future<String> _fakePayment() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    return 'Payment succeeded for order #${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _submitPayment() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _statusText = 'Processing payment...';
    });

    final outcome = await _pay.run(_fakePayment);

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (outcome case OperationSuccess(:final value)) {
      setState(() {
        _statusText = value;
      });
    } else if (outcome case OperationIgnoredAsDuplicate()) {
      setState(() {
        _statusText = 'Duplicate submission ignored.';
      });
    } else if (outcome case OperationFailure()) {
      setState(() {
        _statusText = 'Payment failed.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Duplicate Submission')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tap the pay button rapidly. Without firstWins, each tap fires '
              'a separate payment request. With StateFence, only the first is '
              'processed and the rest are ignored as duplicates.',
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitPayment,
              child: const Text('Pay Now'),
            ),
            const SizedBox(height: 16),
            Text(_statusText),
            const Spacer(),
            ViolationsPanel(
              violations: _diag.reporter.violations,
              eventCount: _diag.timeline.length,
            ),
          ],
        ),
      ),
    );
  }
}
