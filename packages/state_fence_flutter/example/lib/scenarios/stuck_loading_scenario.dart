import 'dart:async';

import 'package:flutter/material.dart';
import 'package:state_fence/state_fence.dart';
import 'package:state_fence_flutter/state_fence_flutter.dart';

import '../main.dart';
import '../widgets/violations_panel.dart';

/// Demonstrates a stuck loading state that never resolves.
///
/// Without StateFence, the loading indicator spins forever. With a
/// [GuardedOperation] timeout, a violation is reported after the configured
/// duration, allowing the UI to show an error state.
class StuckLoadingScenario extends StatefulWidget {
  const StuckLoadingScenario({super.key});

  @override
  State<StuckLoadingScenario> createState() => _StuckLoadingScenarioState();
}

class _StuckLoadingScenarioState extends State<StuckLoadingScenario>
    with StateFenceStateMixin {
  late final SharedDiagnostics _diag = SharedDiagnostics();
  late final GuardedOperation<String> _refresh = fenceOwner.register(
    GuardedOperation<String>(
      name: 'refresh',
      policy: OperationPolicy.latestWins,
      timeout: const Duration(seconds: 3),
      reporter: _diag.reporter,
      timeline: _diag.timeline,
    ),
  );

  String _statusText = 'Ready to refresh.';
  bool _isLoading = false;

  Future<void> _startRefresh() async {
    setState(() {
      _isLoading = true;
      _statusText = 'Loading... (will time out)';
    });

    // This repository call never completes. The GuardedOperation timeout
    // resolves the future with OperationTimedOut after 3 seconds, so the UI
    // is never stuck.
    final outcome = await _refresh.run(() => Completer<String>().future);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (outcome case OperationTimedOut(:final timeout)) {
      setState(() {
        _statusText = 'Refresh timed out after $timeout. Try again.';
      });
    } else if (outcome case OperationSuccess(:final value)) {
      setState(() {
        _statusText = value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stuck Loading')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This refresh call never completes. Without a timeout, the '
              'loading state persists forever. With StateFence, a timeout '
              'violation is reported after 3 seconds.',
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _startRefresh,
              child: const Text('Pull to Refresh'),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const CircularProgressIndicator()
            else
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
