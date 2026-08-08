import 'package:flutter/material.dart';
import 'package:state_fence/state_fence.dart';

/// A panel showing collected violations and the timeline event count.
///
/// This is a development aid for the example app. It is not part of the
/// public StateFence API.
class ViolationsPanel extends StatelessWidget {
  final List<StateFenceViolation> violations;
  final int eventCount;

  const ViolationsPanel({
    super.key,
    required this.violations,
    required this.eventCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Diagnostics: ${violations.length} violation(s), '
            '$eventCount timeline event(s)',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          if (violations.isEmpty)
            const Text('No violations recorded.')
          else
            ...violations.map(
              (v) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '• ${v.reason}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
