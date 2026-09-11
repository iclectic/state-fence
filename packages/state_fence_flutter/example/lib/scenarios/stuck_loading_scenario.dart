import 'dart:async';

import 'package:flutter/material.dart';
import 'package:state_fence/state_fence.dart';
import 'package:state_fence_flutter/state_fence_flutter.dart';

import '../diagnostics.dart';
import '../widgets/diagnostics_panel.dart';
import '../widgets/scenario_page.dart';
import '../widgets/status_pill.dart';

/// Demonstrates a stuck loading state that never resolves.
///
/// Without StateFence, the loading indicator spins forever. With a
/// [GuardedOperation] timeout, the operation resolves with an
/// [OperationTimedOut] outcome after the configured duration, so the UI can
/// recover instead of hanging.
class StuckLoadingScenario extends StatefulWidget {
  /// Creates the stuck loading scenario screen.
  const StuckLoadingScenario({super.key});

  @override
  State<StuckLoadingScenario> createState() => _StuckLoadingScenarioState();
}

const Color _accent = Color(0xFFF59E0B);

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

  bool _loading = false;
  String? _statusText;
  StatusTone _tone = StatusTone.neutral;

  Future<void> _startRefresh() async {
    setState(() {
      _loading = true;
      _statusText = null;
    });

    // This request never completes; the timeout resolves the outcome.
    final OperationOutcome<String> outcome =
        await _refresh.run(() => Completer<String>().future);

    if (!mounted) return;
    setState(() {
      _loading = false;
      if (outcome case OperationTimedOut(:final timeout)) {
        _tone = StatusTone.warning;
        _statusText = 'Refresh timed out after ${timeout.inSeconds}s. '
            'The UI recovered instead of hanging.';
      } else if (outcome case OperationSuccess(:final value)) {
        _tone = StatusTone.success;
        _statusText = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return ScenarioPage(
      title: 'Stuck Loading',
      icon: Icons.hourglass_top_rounded,
      accent: _accent,
      problem: 'A pull to refresh calls a request that never completes. The '
          'spinner stays on screen forever and the user is stuck.',
      solution:
          'A GuardedOperation timeout resolves the outcome after 3 seconds '
          'and records a violation, so the UI can show a recoverable error.',
      children: [
        FilledButton.icon(
          onPressed: _loading ? null : _startRefresh,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(_loading ? 'Loading...' : 'Start refresh (never ends)'),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: _loading
                  ? Column(
                      children: [
                        const SizedBox(
                          height: 40,
                          width: 40,
                          child: CircularProgressIndicator(),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading... resolves via timeout in 3s',
                          style: text.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    )
                  : _statusText == null
                      ? Text(
                          'Idle. Start a refresh to see the timeout guard.',
                          style: text.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        )
                      : Column(
                          children: [
                            StatusPill(
                              label: 'Timed out',
                              tone: _tone,
                              icon: Icons.timer_off_outlined,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _statusText!,
                              textAlign: TextAlign.center,
                              style: text.bodyMedium,
                            ),
                          ],
                        ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        DiagnosticsPanel(
          violations: _diag.reporter.violations,
          eventCount: _diag.timeline.length,
        ),
      ],
    );
  }
}
