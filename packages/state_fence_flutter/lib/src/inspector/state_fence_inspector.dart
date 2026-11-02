import 'package:flutter/material.dart';
import 'package:state_fence/state_fence.dart';

/// An opt-in, on-device view of a [Timeline] and caller-supplied violations.
///
/// Nothing is registered globally, stored, or sent. Pass the timeline the
/// fence already records into, and rebuild this widget when that timeline or
/// the violation list changes.
class StateFenceInspector extends StatelessWidget {
  /// Creates an inspector for [timeline].
  ///
  /// [violations] are shown as supplied. [maxEvents] limits how many of the
  /// newest timeline events are listed.
  const StateFenceInspector({
    super.key,
    required this.timeline,
    this.violations = const <StateFenceViolation>[],
    this.maxEvents = 8,
  }) : assert(maxEvents > 0, 'maxEvents must be greater than zero');

  /// The timeline to display. Read during [build].
  final Timeline timeline;

  /// Violations the caller has collected. This widget does not subscribe to a
  /// reporter.
  final List<StateFenceViolation> violations;

  /// How many of the newest timeline events to list.
  final int maxEvents;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final List<FenceEvent> events = timeline.events;
    final int hidden =
        events.length > maxEvents ? events.length - maxEvents : 0;
    final List<FenceEvent> visible =
        hidden == 0 ? events : events.sublist(hidden);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.insights_outlined, color: scheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'StateFence inspector',
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'On-device view of this timeline. Nothing is sent.',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (timeline.droppedCount > 0) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Dropped ${timeline.droppedCount} older events.',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Violations',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            if (violations.isEmpty)
              Text(
                'No violations recorded.',
                style:
                    text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              )
            else
              for (final StateFenceViolation violation in violations)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(violation.reason, style: text.bodyMedium),
                ),
            const SizedBox(height: 8),
            Text(
              'Timeline',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            if (visible.isEmpty)
              Text(
                'No events recorded.',
                style:
                    text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              )
            else ...<Widget>[
              if (hidden > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '$hidden earlier events are hidden.',
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              for (final FenceEvent event in visible)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${event.kind} · ${event.source} · ${_detail(event)}',
                    style: text.bodyMedium,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

String _detail(FenceEvent event) {
  return switch (event) {
    TransitionAcceptedEvent(:final Type fromState, :final Type toState) =>
      '$fromState to $toState',
    TransitionRejectedEvent(:final StateFenceViolation violation) =>
      violation.reason,
    OperationStartedEvent(:final OperationToken token) =>
      'token ${token.value}',
    OperationSucceededEvent(:final OperationToken token) =>
      'token ${token.value}',
    OperationFailedEvent(:final String errorDescription) => errorDescription,
    OperationIgnoredAsStaleEvent(:final OperationToken token) =>
      'token ${token.value} stale',
    OperationIgnoredAsDuplicateEvent(:final OperationToken token) =>
      'token ${token.value} duplicate',
    OperationTimedOutEvent(:final OperationToken token) =>
      'token ${token.value} timed out',
    StateStuckEvent(:final Type stuckState, :final Duration maxDuration) =>
      '$stuckState exceeded $maxDuration',
    OwnerDisposedEvent() => 'disposed',
  };
}
