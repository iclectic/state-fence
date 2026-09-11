import 'package:flutter/material.dart';
import 'package:state_fence/state_fence.dart';

/// A card that shows collected violations and the timeline event count.
///
/// This is a development aid for the example app. It is not part of the
/// public StateFence API.
class DiagnosticsPanel extends StatelessWidget {
  /// Creates a diagnostics panel for the given [violations] and [eventCount].
  const DiagnosticsPanel({
    super.key,
    required this.violations,
    required this.eventCount,
  });

  /// Violations reported by the fence or operation so far.
  final List<StateFenceViolation> violations;

  /// Number of events recorded on the diagnostic timeline.
  final int eventCount;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final bool hasViolations = violations.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights_outlined, color: scheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Diagnostics',
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                _Count(
                  icon: Icons.report_gmailerrorred_outlined,
                  value: violations.length,
                  tone: hasViolations ? scheme.error : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                _Count(
                  icon: Icons.timeline_outlined,
                  value: eventCount,
                  tone: scheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!hasViolations)
              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'No violations recorded.',
                    style: text.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              )
            else
              ...violations.map(
                (StateFenceViolation v) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 18,
                        color: scheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          v.reason,
                          style: text.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.icon, required this.value, required this.tone});

  final IconData icon;
  final int value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: tone),
        const SizedBox(width: 4),
        Text(
          '$value',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: tone,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}
